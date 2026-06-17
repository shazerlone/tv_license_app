//+------------------------------------------------------------------+
//|                                          CopyTraderBridge.mq4     |
//|   File bridge between an MT4 terminal and CopyTrader Pro.          |
//|                                                                   |
//|   Install on EVERY MT4 terminal you want to use (master or slave):|
//|     1. Copy this file to  <data folder>/MQL4/Experts/             |
//|     2. In MetaEditor press Compile (F7).                          |
//|     3. Attach it to any one chart. Enable "Allow live trading".   |
//|     4. Point the app's mt4_files_path at <data folder>/MQL4/Files |
//|                                                                   |
//|   It writes ct_status.json (account + open orders) continuously   |
//|   and executes ct_cmd_*.json commands (OPEN / CLOSE) from the app.|
//+------------------------------------------------------------------+
#property strict

input int    PollMs       = 500;     // how often to refresh status / read commands
input int    MaxSlippage  = 30;      // points
input int    MagicNumber  = 770077;  // tags copied trades

string STATUS = "ct_status.json";

//+------------------------------------------------------------------+
int OnInit()
  {
   EventSetMillisecondTimer(PollMs);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTimer()
  {
   WriteStatus();
   ProcessCommands();
  }

//+------------------------------------------------------------------+
//| Write account info + all open market orders to ct_status.json    |
//+------------------------------------------------------------------+
void WriteStatus()
  {
   string orders = "";
   int    count  = 0;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue; // market only
      string side = (OrderType()==OP_BUY) ? "BUY" : "SELL";
      if(count>0) orders += ",";
      orders += "{";
      orders += "\"ticket\":"     + IntegerToString(OrderTicket()) + ",";
      orders += "\"symbol\":\""   + OrderSymbol() + "\",";
      orders += "\"type\":\""     + side + "\",";
      orders += "\"lots\":"       + DoubleToString(OrderLots(),2) + ",";
      orders += "\"open_price\":" + DoubleToString(OrderOpenPrice(),5) + ",";
      orders += "\"sl\":"         + DoubleToString(OrderStopLoss(),5) + ",";
      orders += "\"tp\":"         + DoubleToString(OrderTakeProfit(),5) + ",";
      orders += "\"comment\":\""  + OrderComment() + "\"";
      orders += "}";
      count++;
     }

   string json = "{";
   json += "\"login\":"    + IntegerToString(AccountNumber()) + ",";
   json += "\"name\":\""   + AccountName() + "\",";
   json += "\"broker\":\"" + AccountCompany() + "\",";
   json += "\"currency\":\""+ AccountCurrency() + "\",";
   json += "\"balance\":"  + DoubleToString(AccountBalance(),2) + ",";
   json += "\"equity\":"   + DoubleToString(AccountEquity(),2) + ",";
   json += "\"leverage\":" + IntegerToString(AccountLeverage()) + ",";
   json += "\"orders\":["  + orders + "]";
   json += "}";

   int h = FileOpen(STATUS, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h!=INVALID_HANDLE)
     {
      FileWriteString(h, json);
      FileClose(h);
     }
  }

//+------------------------------------------------------------------+
//| Scan for ct_cmd_*.json, execute, write ct_res_<id>.json          |
//+------------------------------------------------------------------+
void ProcessCommands()
  {
   string name;
   long handle = FileFindFirst("ct_cmd_*.json", name);
   if(handle==INVALID_HANDLE) return;
   do
     {
      HandleCommandFile(name);
     }
   while(FileFindNext(handle, name));
   FileFindClose(handle);
  }

void HandleCommandFile(string fname)
  {
   string content = ReadAll(fname);
   if(content=="") { FileDelete(fname); return; }

   // id is the middle of  ct_cmd_<id>.json
   string id  = StringSubstr(fname, 7, StringLen(fname)-7-5);
   string res = "";

   string action = JsonVal(content, "action");
   if(action=="OPEN")
      res = DoOpen(content);
   else if(action=="CLOSE")
      res = DoClose(content);
   else
      res = "{\"ok\":false,\"error\":\"unknown action\"}";

   int h = FileOpen("ct_res_" + id + ".json", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h!=INVALID_HANDLE) { FileWriteString(h, res); FileClose(h); }
   FileDelete(fname);
  }

//+------------------------------------------------------------------+
string DoOpen(string cmd)
  {
   string symbol = JsonVal(cmd, "symbol");
   string side   = JsonVal(cmd, "side");
   double volume = StrToDouble(JsonVal(cmd, "volume"));
   double sl     = StrToDouble(JsonVal(cmd, "sl"));
   double tp     = StrToDouble(JsonVal(cmd, "tp"));
   string cmt    = JsonVal(cmd, "comment");

   int type    = (side=="BUY") ? OP_BUY : OP_SELL;
   double price = (side=="BUY") ? MarketInfo(symbol, MODE_ASK)
                                : MarketInfo(symbol, MODE_BID);
   if(price<=0)
      return "{\"ok\":false,\"error\":\"no price for " + symbol + "\"}";

   int ticket = OrderSend(symbol, type, volume, price, MaxSlippage,
                          sl, tp, cmt, MagicNumber, 0, clrNONE);
   if(ticket<0)
      return "{\"ok\":false,\"error\":\"OrderSend " + IntegerToString(GetLastError()) + "\"}";
   return "{\"ok\":true,\"ticket\":" + IntegerToString(ticket) + "}";
  }

string DoClose(string cmd)
  {
   int ticket = (int)StrToInteger(JsonVal(cmd, "ticket"));
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return "{\"ok\":false,\"error\":\"ticket not found\"}";
   double price = (OrderType()==OP_BUY) ? MarketInfo(OrderSymbol(), MODE_BID)
                                        : MarketInfo(OrderSymbol(), MODE_ASK);
   if(OrderClose(ticket, OrderLots(), price, MaxSlippage, clrNONE))
      return "{\"ok\":true}";
   return "{\"ok\":false,\"error\":\"OrderClose " + IntegerToString(GetLastError()) + "\"}";
  }

//+------------------------------------------------------------------+
//| Minimal helpers                                                  |
//+------------------------------------------------------------------+
string ReadAll(string fname)
  {
   int h = FileOpen(fname, FILE_READ|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return "";
   string s = "";
   while(!FileIsEnding(h)) s += FileReadString(h);
   FileClose(h);
   return s;
  }

// Extract a flat JSON value by key (string or number), no nesting needed.
string JsonVal(string json, string key)
  {
   int p = StringFind(json, "\"" + key + "\"");
   if(p<0) return "";
   p = StringFind(json, ":", p);
   if(p<0) return "";
   p++;
   int n = StringLen(json);
   while(p<n && StringGetChar(json,p)==' ') p++;
   bool quoted = false;
   if(p<n && StringGetChar(json,p)=='"') { quoted=true; p++; }
   string val = "";
   while(p<n)
     {
      int c = StringGetChar(json, p);
      if(quoted && c=='"') break;
      if(!quoted && (c==',' || c=='}')) break;
      val += CharToStr((uchar)c);
      p++;
     }
   return val;
  }
//+------------------------------------------------------------------+
