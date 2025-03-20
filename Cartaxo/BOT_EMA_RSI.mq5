#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\CommonParams.mqh>
#include <.\MyMagicNumber.mqh>

// Structure to hold currency pair specific data
struct CurrencyData {
    string symbol;
    int handleFast;
    int handleSlow;
    int handleStoch;
    int handleRSI;
    double bufferFast[];
    double bufferSlow[];
    double bufferStoch[];
    double bufferRSI[];
    int totalBars;
};

// Global variables
CurrencyData currencyPairs[];
MyPainel painel;
MyMagicNumber myMagicNumber;
TraderInfos tradeInfos;
MyCtrader trade;


input group "==== Params EMA ===="
input int inputFastPeriodo = 5;
input int inputSlowPeriodo = 10;
input ENUM_TIMEFRAMES inputTimeFrameEMA = PERIOD_M5;

input group "==== Params IFR ===="
input int iIFRPeriod = 14;
input ENUM_TIMEFRAMES iIFRTimeFrame = PERIOD_M5;
input ENUM_APPLIED_PRICE iIFRAppliedPrice = PRICE_CLOSE;
input int irRSILevelUpper = 70;
input int irRSILevelLower = 30;

input group "==== Params Stochastic ===="
input ENUM_TIMEFRAMES iStoTimeFrame = PERIOD_M5;
input int iStoKperiod = 5;
input int iStoDperiod = 5;
input int iStoSlowing = 3;
input ENUM_MA_METHOD iStoMAMethod = MODE_SMA;
input ENUM_STO_PRICE iStoPriceField = STO_LOWHIGH;
input int iStoLevelUpper = 80;
input int iStoLevelLower = 20;

// Initialize currency pair data
void InitializeCurrencyPair(string symbol) {
    int index = ArraySize(currencyPairs);
    ArrayResize(currencyPairs, index + 1);
    
    currencyPairs[index].symbol = symbol;
    currencyPairs[index].totalBars = 0;
    
    // Initialize indicators
    currencyPairs[index].handleFast = iMA(symbol, inputTimeFrameEMA, inputFastPeriodo, 0, MODE_SMA, PRICE_CLOSE);
    currencyPairs[index].handleSlow = iMA(symbol, inputTimeFrameEMA, inputSlowPeriodo, 0, MODE_SMA, PRICE_CLOSE);
    currencyPairs[index].handleStoch = iStochastic(symbol, iStoTimeFrame, iStoKperiod, iStoDperiod, iStoSlowing, iStoMAMethod, iStoPriceField);
    currencyPairs[index].handleRSI = iRSI(symbol, iIFRTimeFrame, iIFRPeriod, iIFRAppliedPrice);
    
    // Initialize arrays
    ArraySetAsSeries(currencyPairs[index].bufferFast, true);
    ArraySetAsSeries(currencyPairs[index].bufferSlow, true);
    ArraySetAsSeries(currencyPairs[index].bufferStoch, true);
    ArraySetAsSeries(currencyPairs[index].bufferRSI, true);
}

int OnInit() {
    // Split currency pairs string and initialize each pair
    string pairs[];
    StringSplit(currencies, ',', pairs);
    
    for(int i = 0; i < ArraySize(pairs); i++) {
        InitializeCurrencyPair(pairs[i]);
    }
    
    // Verify all handles are valid
    for(int i = 0; i < ArraySize(currencyPairs); i++) {
        if(currencyPairs[i].handleFast == INVALID_HANDLE || 
           currencyPairs[i].handleSlow == INVALID_HANDLE ||
           currencyPairs[i].handleStoch == INVALID_HANDLE ||
           currencyPairs[i].handleRSI == INVALID_HANDLE) {
            Print("Failed to create indicator handles for ", currencyPairs[i].symbol);
            return INIT_FAILED;
        }
    }
    
    tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), painel.getShortCurrencies());
    
    if(!painel.OnInit(myMagicNumber.magicNumber)) {
        return INIT_FAILED;
    }
    
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    for(int i = 0; i < ArraySize(currencyPairs); i++) {
        IndicatorRelease(currencyPairs[i].handleFast);
        IndicatorRelease(currencyPairs[i].handleSlow);
        IndicatorRelease(currencyPairs[i].handleStoch);
        IndicatorRelease(currencyPairs[i].handleRSI);
        
        ArrayFree(currencyPairs[i].bufferFast);
        ArrayFree(currencyPairs[i].bufferSlow);
        ArrayFree(currencyPairs[i].bufferStoch);
        ArrayFree(currencyPairs[i].bufferRSI);
    }
    
    painel.Destroy(reason);
    delete &tradeInfos;
    EventKillTimer();
}

void ProcessCurrencyPair(CurrencyData &pair) {
    int bars = iBars(pair.symbol, _Period);
    if(pair.totalBars == bars) return;
    pair.totalBars = bars;
    
    // Copy indicator data
    if(!CopyBuffer(pair.handleFast, 0, 0, 3, pair.bufferFast) ||
       !CopyBuffer(pair.handleSlow, 0, 0, 3, pair.bufferSlow) ||
       !CopyBuffer(pair.handleStoch, MAIN_LINE, 1, 2, pair.bufferStoch) ||
       !CopyBuffer(pair.handleRSI, 0, 1, 2, pair.bufferRSI)) {
        Print("Problem loading indicator data for ", pair.symbol);
        return;
    }
    
    if(HasPosition(myMagicNumber.magicNumber) != 0) return;
    
    double price_step = SymbolInfoDouble(pair.symbol, SYMBOL_TRADE_TICK_SIZE);
    double lots = SymbolInfoDouble(pair.symbol, SYMBOL_VOLUME_MIN) + iRangeLotes;
    
    // EMA calculations
    double fastMA1 = pair.bufferFast[0];
    double slowMA1 = pair.bufferSlow[0];
    double fastMA2 = pair.bufferFast[1];
    double slowMA2 = pair.bufferSlow[1];
    
    // BUY LOGIC
    if(fastMA1 > slowMA1 && !(fastMA2 > slowMA2)) {
        if(pair.bufferStoch[0] < iStoLevelUpper && irRSILevelLower > pair.bufferRSI[0]) {
            double entry_price = SymbolInfoDouble(pair.symbol, SYMBOL_ASK);
            double sl = roundPriceH9K(entry_price - 200 * _Point, price_step);
            double tp = roundPriceH9K(entry_price + 400 * _Point, price_step);
            
            tradeInfos.symbol = pair.symbol;
            tradeInfos.lot_size = lots;
            tradeInfos.amount = entry_price;
            tradeInfos.order_type = ORDER_TYPE_BUY;
            tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl;
            tradeInfos.take_profit = tp;
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + pair.symbol;
            
            trade.sendOrder(tradeInfos);
        }
    }
    // SELL LOGIC
    else if(fastMA1 < slowMA1 && !(fastMA2 < slowMA2)) {
        if(pair.bufferStoch[0] > iStoLevelLower && irRSILevelUpper < pair.bufferRSI[0]) {
            double entry_price = SymbolInfoDouble(pair.symbol, SYMBOL_BID);
            double sl = roundPriceH9K(entry_price + 200 * _Point, price_step);
            double tp = roundPriceH9K(entry_price - 400 * _Point, price_step);
            
            tradeInfos.symbol = pair.symbol;
            tradeInfos.lot_size = lots;
            tradeInfos.amount = entry_price;
            tradeInfos.order_type = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl;
            tradeInfos.take_profit = tp;
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + pair.symbol;
            
            trade.sendOrder(tradeInfos);
        }
    }
}

void OnTick() {
    painel.OnTick();
    
    for(int i = 0; i < ArraySize(currencyPairs); i++) {
        ProcessCurrencyPair(currencyPairs[i]);
    }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    painel.PanelChartEvent(id, lparam, dparam, sparam);
}

void OnTimer() {
    painel.OnTimer();
}