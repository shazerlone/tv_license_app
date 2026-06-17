//+------------------------------------------------------------------+
//|  Slave_Receiver.mq5                                              |
//|  MT5 Slave — reads trade signals from Master_Sender.mq4 and     |
//|  mirrors them on this account at lightning speed.                |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//--- Inputs
input string SlaveSymbol     = "XAU_CASH";  // Symbol on this (slave) account
input string MasterSymbol    = "XAUUSD";    // Master symbol (for reference only)
input double LotMultiplier   = 100.0;       // Already applied by master EA; set 1.0 if master handles it
input int    SlaveMagic      = 99002;       // Magic number for slave trades
input string SignalFile      = "mt_copier_signal.csv"; // Must match Master_Sender setting
input int    TimerMs         = 10;          // Polling interval in ms (10ms ≈ lightning)
input int    MaxSlippage     = 30;          // Max allowed slippage in points
input bool   EnableLogging   = true;

//--- Globals
CTrade  trade;
string  lastProcessedLine = "";  // Deduplicate: don't re-process same signal twice

// Ticket mapping: master_ticket → slave_ticket
struct TicketMap {
    long masterTicket;
    ulong slaveTicket;
};
TicketMap ticketMap[];
int       mapCount = 0;

//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(SlaveMagic);
    trade.SetDeviationInPoints(MaxSlippage);
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    if(TimerMs < 1) {
        Alert("Slave_Receiver: TimerMs must be >= 1");
        return INIT_PARAMETERS_INCORRECT;
    }
    EventSetMillisecondTimer(TimerMs);
    Log("Slave_Receiver initialized. Symbol: " + SlaveSymbol +
        " | Magic: " + IntegerToString(SlaveMagic) +
        " | File: " + SignalFile);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
}

//+------------------------------------------------------------------+
void OnTimer() {
    ReadAndExecuteSignal();
}

//+------------------------------------------------------------------+
void ReadAndExecuteSignal() {
    if(!FileIsExist(SignalFile, FILE_COMMON)) return;

    int h = FileOpen(SignalFile, FILE_READ | FILE_TXT | FILE_COMMON | FILE_SHARE_READ);
    if(h == INVALID_HANDLE) return;

    string line = FileReadString(h);
    FileClose(h);

    line = StringTrimRight(StringTrimLeft(line));
    if(line == "" || line == lastProcessedLine) return;

    lastProcessedLine = line;
    Log("Signal received: " + line);

    // Parse CSV: ACTION,MASTERTICKET,SYMBOL,TYPE,LOTS,PRICE,SL,TP,TIMESTAMP
    string parts[];
    int n = StringSplit(line, ',', parts);
    if(n < 9) {
        Log("ERROR: malformed signal line (" + IntegerToString(n) + " fields): " + line);
        return;
    }

    string action      = parts[0];
    long   masterTicket = StringToInteger(parts[1]);
    string sym         = parts[2];   // already mapped to SlaveSymbol by master EA
    int    orderType   = (int)StringToInteger(parts[3]);
    double lots        = StringToDouble(parts[4]);
    double openPrice   = StringToDouble(parts[5]);
    double sl          = StringToDouble(parts[6]);
    double tp          = StringToDouble(parts[7]);

    // Override symbol with our configured slave symbol (extra safety)
    if(sym == MasterSymbol) sym = SlaveSymbol;

    if(action == "OPEN")   ProcessOpen(masterTicket, sym, orderType, lots, sl, tp);
    else if(action == "CLOSE")  ProcessClose(masterTicket);
    else if(action == "MODIFY") ProcessModify(masterTicket, sl, tp);
    else Log("Unknown action: " + action);
}

//+------------------------------------------------------------------+
void ProcessOpen(long masterTicket, string sym, int mt4Type, double lots,
                 double sl, double tp) {
    // Avoid duplicates
    if(FindSlaveTicket(masterTicket) != 0) {
        Log("Already opened slave trade for master ticket " + IntegerToString(masterTicket));
        return;
    }

    bool result = false;
    if(mt4Type == 0) // OP_BUY
        result = trade.Buy(lots, sym, 0, sl, tp, "Master#" + IntegerToString(masterTicket));
    else if(mt4Type == 1) // OP_SELL
        result = trade.Sell(lots, sym, 0, sl, tp, "Master#" + IntegerToString(masterTicket));
    else {
        Log("Unsupported order type: " + IntegerToString(mt4Type));
        return;
    }

    if(result) {
        ulong slaveTicket = trade.ResultOrder();
        AddMap(masterTicket, slaveTicket);
        Log("Opened slave trade #" + IntegerToString((int)slaveTicket) +
            " for master #" + IntegerToString(masterTicket) +
            " | Lots: " + DoubleToString(lots, 2));
    } else {
        Log("ERROR opening trade: " + IntegerToString(trade.ResultRetcode()) +
            " — " + trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
void ProcessClose(long masterTicket) {
    ulong slaveTicket = FindSlaveTicket(masterTicket);
    if(slaveTicket == 0) {
        Log("No slave ticket found for master #" + IntegerToString(masterTicket));
        return;
    }

    if(trade.PositionClose(slaveTicket)) {
        Log("Closed slave trade #" + IntegerToString((int)slaveTicket));
        RemoveMap(masterTicket);
    } else {
        // Fallback: find by magic and symbol if ticket lookup fails
        if(CloseByMagicAndSymbol()) {
            RemoveMap(masterTicket);
        } else {
            Log("ERROR closing trade: " + IntegerToString(trade.ResultRetcode()));
        }
    }
}

//+------------------------------------------------------------------+
void ProcessModify(long masterTicket, double sl, double tp) {
    ulong slaveTicket = FindSlaveTicket(masterTicket);
    if(slaveTicket == 0) {
        Log("No slave ticket found for master #" + IntegerToString(masterTicket));
        return;
    }

    if(!PositionSelectByTicket(slaveTicket)) {
        Log("Cannot select slave position #" + IntegerToString((int)slaveTicket));
        return;
    }

    if(trade.PositionModify(slaveTicket, sl, tp))
        Log("Modified slave #" + IntegerToString((int)slaveTicket) +
            " SL=" + DoubleToString(sl, 5) + " TP=" + DoubleToString(tp, 5));
    else
        Log("ERROR modifying trade: " + IntegerToString(trade.ResultRetcode()));
}

//+------------------------------------------------------------------+
//  Fallback: close any open position by magic + symbol
//+------------------------------------------------------------------+
bool CloseByMagicAndSymbol() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if((long)PositionGetInteger(POSITION_MAGIC) == SlaveMagic &&
               PositionGetString(POSITION_SYMBOL) == SlaveSymbol) {
                if(trade.PositionClose(ticket)) return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//  Ticket map helpers
//+------------------------------------------------------------------+
ulong FindSlaveTicket(long masterTicket) {
    for(int i = 0; i < mapCount; i++)
        if(ticketMap[i].masterTicket == masterTicket)
            return ticketMap[i].slaveTicket;
    return 0;
}

void AddMap(long masterTicket, ulong slaveTicket) {
    ArrayResize(ticketMap, mapCount + 1);
    ticketMap[mapCount].masterTicket = masterTicket;
    ticketMap[mapCount].slaveTicket  = slaveTicket;
    mapCount++;
}

void RemoveMap(long masterTicket) {
    for(int i = 0; i < mapCount; i++) {
        if(ticketMap[i].masterTicket == masterTicket) {
            for(int j = i; j < mapCount - 1; j++)
                ticketMap[j] = ticketMap[j + 1];
            mapCount--;
            ArrayResize(ticketMap, mapCount);
            return;
        }
    }
}

//+------------------------------------------------------------------+
void Log(string msg) {
    if(EnableLogging)
        Print("[Slave_Receiver] " + msg);
}
//+------------------------------------------------------------------+
