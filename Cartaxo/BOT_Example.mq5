//+------------------------------------------------------------------+
//|                                                      SimpleEA.mq5 |
//|                                  Copyright 2024, Rodrigo Cartaxo. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rodrigo Cartaxo."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <.\MyPainelV2.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== EA Settings ==="
input int      EA1_MagicNumber = 123456;    // EA1 Magic Number
input int      EA2_MagicNumber = 234567;    // EA2 Magic Number
input double   EA1_Lots        = 0.1;       // EA1 Lot Size
input double   EA2_Lots        = 0.1;       // EA2 Lot Size
input int      EA1_StopLoss    = 100;       // EA1 Stop Loss (points)
input int      EA2_StopLoss    = 150;       // EA2 Stop Loss (points)
input int      EA1_TakeProfit  = 200;       // EA1 Take Profit (points)
input int      EA2_TakeProfit  = 300;       // EA2 Take Profit (points)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
MyPainel Panel;              // Panel instance
CTrade Trade;                // Trade instance
ulong MagicNumbers[];        // Array to store magic numbers
datetime LastTradeTime = 0;  // Last trade time
int HandleRSI;              // RSI handle for EA1
int HandleMA;               // MA handle for EA2

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Initialize magic numbers array
    ArrayResize(MagicNumbers, 2);
    MagicNumbers[0] = EA1_MagicNumber;
    MagicNumbers[1] = EA2_MagicNumber;
    
    // Initialize panel
    if(!Panel.OnInit(MagicNumbers)) {
        Print("Failed to initialize panel");
        return INIT_FAILED;
    }
    
    // Initialize indicators
    HandleRSI = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    HandleMA = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    
    if(HandleRSI == INVALID_HANDLE || HandleMA == INVALID_HANDLE) {
        Print("Failed to create indicators");
        return INIT_FAILED;
    }
    
    // Set chart properties
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(HandleRSI);
    IndicatorRelease(HandleMA);
    Panel.Destroy();
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick() {
    
    // Basic check to avoid too frequent trades
    if(TimeCurrent() - LastTradeTime < 60) return;
    
    // Process EA1 Strategy (RSI based)
    ProcessEA1Strategy();
    
    // Process EA2 Strategy (MA based)
    ProcessEA2Strategy();
}


//+------------------------------------------------------------------+
//| ChartEvent function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
    Panel.PanelChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| EA1 Strategy - RSI Based                                        |
//+------------------------------------------------------------------+
void ProcessEA1Strategy() {
    double rsiValues[];
    ArraySetAsSeries(rsiValues, true);
    
    if(CopyBuffer(HandleRSI, 0, 0, 2, rsiValues) != 2) return;
    
    Trade.SetExpertMagicNumber(EA1_MagicNumber);
    
    // Check if there are no open positions for EA1
    if(PositionsTotal() == 0) {
        // RSI oversold condition (buy)
        if(rsiValues[0] < 30) {
            double sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - EA1_StopLoss * _Point;
            double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) + EA1_TakeProfit * _Point;
            
            if(Trade.Buy(EA1_Lots, _Symbol, 0, sl, tp)) {
                LastTradeTime = TimeCurrent();
            }
        }
        // RSI overbought condition (sell)
        else if(rsiValues[0] > 70) {
            double sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + EA1_StopLoss * _Point;
            double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - EA1_TakeProfit * _Point;
            
            if(Trade.Sell(EA1_Lots, _Symbol, 0, sl, tp)) {
                LastTradeTime = TimeCurrent();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| EA2 Strategy - Moving Average Based                             |
//+------------------------------------------------------------------+
void ProcessEA2Strategy() {
    double maValues[];
    ArraySetAsSeries(maValues, true);
    
    if(CopyBuffer(HandleMA, 0, 0, 2, maValues) != 2) return;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) != 2) return;
    
    Trade.SetExpertMagicNumber(EA2_MagicNumber);
    
    // Check if there are no open positions for EA2
    if(PositionsTotal() == 0) {
        // Price crosses above MA (buy)
        if(rates[1].close < maValues[1] && rates[0].close > maValues[0]) {
            double sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - EA2_StopLoss * _Point;
            double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) + EA2_TakeProfit * _Point;
            
            if(Trade.Buy(EA2_Lots, _Symbol, 0, sl, tp)) {
                LastTradeTime = TimeCurrent();
            }
        }
        // Price crosses below MA (sell)
        else if(rates[1].close > maValues[1] && rates[0].close < maValues[0]) {
            double sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + EA2_StopLoss * _Point;
            double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - EA2_TakeProfit * _Point;
            
            if(Trade.Sell(EA2_Lots, _Symbol, 0, sl, tp)) {
                LastTradeTime = TimeCurrent();
            }
        }
    }
}