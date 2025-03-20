#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>

// Structure to hold currency pair specific data
struct CurrencyData {
    int handleAlligator;
    double jawsBuffer[];
    double teethBuffer[];
    double lipsBuffer[];
    double lastSellEntryPrice;
    double lastBuyEntryPrice;
    datetime lastOrderTime;
    string symbol;
};

// Global variables
CurrencyData currencyPairs[];
MyPainel painel;
MyMagicNumber myMagicNumber;
TraderInfos tradeInfos;
MyCtrader trade;

input group "==== Alligator Parameters ===="
input int iJawperiod = 13;
input int iJawShift = 8;
input int iTeethPeriod = 8;
input int iTeethShift = 5;
input int iLipsPeriod = 5;
input int iLipsShift = 3;
input ENUM_MA_METHOD iMamethod = MODE_SMMA;
input ENUM_APPLIED_PRICE iAppliedPrice = PRICE_CLOSE;
input ENUM_TIMEFRAMES inputTimeFrame = PERIOD_M5;

input group "==== Trading Parameters ===="
input int minOrderInterval = 60;       // Minimum time between orders in seconds
input double minPriceDifference = 10;  // Minimum price difference for new orders in points


// Initialize currency pair data
void InitializeCurrencyPair(string symbol) {

    int index = ArraySize(currencyPairs);
    ArrayResize(currencyPairs, index + 1);
    
    currencyPairs[index].symbol = symbol;
    currencyPairs[index].handleAlligator = iAlligator(
        symbol, 
        inputTimeFrame,
        iJawperiod,
        iJawShift,
        iTeethPeriod,
        iTeethShift,
        iLipsPeriod,
        iLipsShift,
        iMamethod,
        iAppliedPrice
    );
    
    ArraySetAsSeries(currencyPairs[index].jawsBuffer, true);
    ArraySetAsSeries(currencyPairs[index].teethBuffer, true);
    ArraySetAsSeries(currencyPairs[index].lipsBuffer, true);
    
    currencyPairs[index].lastSellEntryPrice = 0;
    currencyPairs[index].lastBuyEntryPrice = 0;
    currencyPairs[index].lastOrderTime = 0;
}

int OnInit() {
    // Split currency pairs string and initialize each pair
    string pairs[];
    StringSplit(currencies, ',', pairs);
    
    for(int i = 0; i < ArraySize(pairs); i++) {
        InitializeCurrencyPair(pairs[i]);
    }
    
    // Check if all handles are valid
    for(int i = 0; i < ArraySize(currencyPairs); i++) {
        if(currencyPairs[i].handleAlligator == INVALID_HANDLE) {
            Print("Failed to create Alligator indicator handle for ", currencyPairs[i].symbol);
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
        IndicatorRelease(currencyPairs[i].handleAlligator);
        ArrayFree(currencyPairs[i].jawsBuffer);
        ArrayFree(currencyPairs[i].teethBuffer);
        ArrayFree(currencyPairs[i].lipsBuffer);
    }
    
    painel.Destroy(reason);
    delete &tradeInfos;
    EventKillTimer();
}

bool CanPlaceNewOrder(CurrencyData &currencyData, double currentEntryPrice, double lastEntryPrice) {
    if(TimeCurrent() - currencyData.lastOrderTime < minOrderInterval) {
        return false;
    }
    
    double priceDiff = MathAbs(currentEntryPrice - lastEntryPrice);
    double pointDiff = priceDiff / SymbolInfoDouble(currencyData.symbol, SYMBOL_POINT);
    
    return pointDiff >= minPriceDifference;
}

void ProcessCurrencyPair(CurrencyData &currencyData) {
   
    if(!CopyBuffer(currencyData.handleAlligator, GATORJAW_LINE, 0, 2, currencyData.jawsBuffer)) return;
    if(!CopyBuffer(currencyData.handleAlligator, GATORTEETH_LINE, 0, 2, currencyData.teethBuffer)) return;
    if(!CopyBuffer(currencyData.handleAlligator, GATORLIPS_LINE, 0, 2, currencyData.lipsBuffer)) return;
    
    if(HasPosition(tradeInfos.iMagicNumber, currencyData.symbol) != 0) return;
    
    double price_step = SymbolInfoDouble(currencyData.symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Check for sell signal
    if(currencyData.lipsBuffer[0] > currencyData.teethBuffer[0] && 
       currencyData.lipsBuffer[0] > currencyData.jawsBuffer[0] && 
       currencyData.teethBuffer[0] > currencyData.jawsBuffer[0] && 
       currencyData.teethBuffer[1] < currencyData.jawsBuffer[1]) {
        
        double entry_price = SymbolInfoDouble(currencyData.symbol, SYMBOL_BID);
        
        if(CanPlaceNewOrder(currencyData, entry_price, currencyData.lastSellEntryPrice)) {
            double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent / 100), price_step);
            double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent / 100), price_step);
            
            tradeInfos.symbol = currencyData.symbol;
            tradeInfos.amount = entry_price;
            tradeInfos.order_type = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl;
            tradeInfos.take_profit = tp;
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + currencyData.symbol;
            
            trade.sendOrder(tradeInfos);
            currencyData.lastSellEntryPrice = entry_price;
            currencyData.lastOrderTime = TimeCurrent();
        }
    }
    // Check for buy signal
    else if(currencyData.lipsBuffer[0] < currencyData.teethBuffer[0] && 
            currencyData.lipsBuffer[0] < currencyData.jawsBuffer[0] && 
            currencyData.teethBuffer[0] < currencyData.jawsBuffer[0] && 
            currencyData.teethBuffer[1] > currencyData.jawsBuffer[1]) {
        
        double entry_price = SymbolInfoDouble(currencyData.symbol, SYMBOL_ASK);
        
        if(CanPlaceNewOrder(currencyData, entry_price, currencyData.lastBuyEntryPrice)) {
            double sl = roundPriceH9K(entry_price - (entry_price * iStopLossPercent / 100), price_step);
            double tp = roundPriceH9K(entry_price + (entry_price * iTakeProfitPercent / 100), price_step);
            
            tradeInfos.symbol = currencyData.symbol;
            tradeInfos.amount = entry_price;
            tradeInfos.order_type = ORDER_TYPE_BUY;
            tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl;
            tradeInfos.take_profit = tp;
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + currencyData.symbol;
            
            trade.sendOrder(tradeInfos);
            currencyData.lastBuyEntryPrice = entry_price;
            currencyData.lastOrderTime = TimeCurrent();
        }
    }
}

void OnTick() {
    painel.OnTick();
    
    static int prevBars = 0;
    int currentBars = iBars(_Symbol, _Period);
    if(currentBars == prevBars) return;
    prevBars = currentBars;
    
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