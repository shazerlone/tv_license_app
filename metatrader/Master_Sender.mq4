//+------------------------------------------------------------------+
//|  Master_Sender.mq4                                               |
//|  MT4 Master — writes trade signals to a shared CSV file          |
//|  that Slave_Receiver.mq5 reads on the MT5 side.                 |
//+------------------------------------------------------------------+
#property strict

//--- Inputs (all configurable from EA settings panel)
input string MasterSymbol   = "XAUUSD";    // Symbol to watch on this account
input string SlaveSymbol    = "XAU_CASH";  // Symbol name used on slave account
input double LotMultiplier  = 100.0;       // Multiply master lots by this for slave
input int    MagicNumber    = 99001;       // Magic number to stamp on master trades (0 = watch all)
input string SignalFile     = "mt_copier_signal.csv"; // File name in Common folder
input int    TimerMs        = 10;          // Timer interval in milliseconds (10 = ~lightning)
input bool   CopyAllSymbols = false;       // true = copy every symbol, false = MasterSymbol only
input bool   EnableLogging  = true;        // Print log messages to Experts tab

//--- Internal state
struct TradeState {
    int    ticket;
    int    type;      // OP_BUY / OP_SELL
    double lots;
    double openPrice;
    double sl;
    double tp;
    string symbol;
};

TradeState prevState[];
int        prevCount = 0;

//+------------------------------------------------------------------+
int OnInit() {
    if(TimerMs < 1) {
        Alert("Master_Sender: TimerMs must be >= 1");
        return INIT_PARAMETERS_INCORRECT;
    }
    EventSetMillisecondTimer(TimerMs);
    Log("Master_Sender initialized. Watching: " + MasterSymbol +
        " | Multiplier: " + DoubleToStr(LotMultiplier, 2) +
        " | File: " + SignalFile);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
}

//+------------------------------------------------------------------+
void OnTimer() {
    ScanTrades();
}

void OnTick() {
    // Also scan on every tick for the chart symbol so we don't miss fast fills
    ScanTrades();
}

//+------------------------------------------------------------------+
void ScanTrades() {
    int total = OrdersTotal();

    // ---- Detect NEWLY OPENED trades ----
    for(int i = 0; i < total; i++) {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(!ShouldWatch()) continue;

        int ticket = OrderTicket();
        if(!IsKnown(ticket)) {
            AddKnown(ticket, OrderType(), OrderLots(), OrderOpenPrice(),
                     OrderStopLoss(), OrderTakeProfit(), OrderSymbol());
            WriteSignal("OPEN", ticket, OrderSymbol(), OrderType(),
                        OrderLots(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit());
        } else {
            // Detect SL/TP modification
            int idx = FindKnown(ticket);
            if(idx >= 0) {
                if(MathAbs(prevState[idx].sl - OrderStopLoss()) > Point * 0.1 ||
                   MathAbs(prevState[idx].tp - OrderTakeProfit()) > Point * 0.1) {
                    prevState[idx].sl = OrderStopLoss();
                    prevState[idx].tp = OrderTakeProfit();
                    WriteSignal("MODIFY", ticket, OrderSymbol(), OrderType(),
                                OrderLots(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit());
                }
            }
        }
    }

    // ---- Detect CLOSED trades ----
    for(int j = 0; j < prevCount; j++) {
        if(!IsStillOpen(prevState[j].ticket)) {
            WriteSignal("CLOSE", prevState[j].ticket, prevState[j].symbol,
                        prevState[j].type, prevState[j].lots,
                        prevState[j].openPrice, 0, 0);
            RemoveKnown(prevState[j].ticket);
            j--;  // array shrunk
        }
    }
}

//+------------------------------------------------------------------+
bool ShouldWatch() {
    if(CopyAllSymbols) return true;
    return (OrderSymbol() == MasterSymbol);
}

//+------------------------------------------------------------------+
//  File I/O — append a line then rename so MT5 sees an atomic update
//+------------------------------------------------------------------+
void WriteSignal(string action, int ticket, string sym, int type,
                 double lots, double price, double sl, double tp) {

    double slaveLots = NormalizeDouble(lots * LotMultiplier, 2);

    // Map symbol name
    string slaveSym = (sym == MasterSymbol) ? SlaveSymbol : sym;

    string line = action + "," +
                  IntegerToString(ticket) + "," +
                  slaveSym + "," +
                  IntegerToString(type) + "," +
                  DoubleToStr(slaveLots, 2) + "," +
                  DoubleToStr(price, 5) + "," +
                  DoubleToStr(sl, 5) + "," +
                  DoubleToStr(tp, 5) + "," +
                  IntegerToString((int)TimeCurrent()) + "\n";

    // Write to a temp file then rename for near-atomic delivery
    string tmpFile = SignalFile + ".tmp";
    int h = FileOpen(tmpFile, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(h == INVALID_HANDLE) {
        Log("ERROR: cannot open signal file for writing");
        return;
    }
    FileWriteString(h, line);
    FileClose(h);

    // Rename tmp → signal file (overwrites previous unread signal)
    FileDelete(SignalFile, FILE_COMMON);
    FileCopy(tmpFile, FILE_COMMON, SignalFile, FILE_COMMON | FILE_REWRITE);
    FileDelete(tmpFile, FILE_COMMON);

    Log("Signal sent: " + line);
}

//+------------------------------------------------------------------+
//  Ticket tracking helpers
//+------------------------------------------------------------------+
bool IsKnown(int ticket) {
    return FindKnown(ticket) >= 0;
}

int FindKnown(int ticket) {
    for(int i = 0; i < prevCount; i++)
        if(prevState[i].ticket == ticket) return i;
    return -1;
}

void AddKnown(int ticket, int type, double lots, double price,
              double sl, double tp, string sym) {
    ArrayResize(prevState, prevCount + 1);
    prevState[prevCount].ticket    = ticket;
    prevState[prevCount].type      = type;
    prevState[prevCount].lots      = lots;
    prevState[prevCount].openPrice = price;
    prevState[prevCount].sl        = sl;
    prevState[prevCount].tp        = tp;
    prevState[prevCount].symbol    = sym;
    prevCount++;
}

void RemoveKnown(int ticket) {
    int idx = FindKnown(ticket);
    if(idx < 0) return;
    for(int i = idx; i < prevCount - 1; i++)
        prevState[i] = prevState[i + 1];
    prevCount--;
    ArrayResize(prevState, prevCount);
}

bool IsStillOpen(int ticket) {
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderTicket() == ticket)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
void Log(string msg) {
    if(EnableLogging)
        Print("[Master_Sender] " + msg);
}
//+------------------------------------------------------------------+
