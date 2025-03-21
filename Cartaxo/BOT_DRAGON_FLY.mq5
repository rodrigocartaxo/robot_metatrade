//+------------------------------------------------------------------+
//| Multi-Timeframe Gravestone and Dragonfly EA                      |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property version   "2.00"
#property strict

// Include required libraries
#include <Trade\Trade.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>


// Input Parameters
input double   InpLotSize       = 0.1;        // Lot Size
input int      InpStopLoss      = 50;         // Stop Loss in Points
input int      InpTakeProfit    = 100;        // Take Profit in Points

// Global Variables
int TimeFrames[] = {PERIOD_M15, PERIOD_M30, PERIOD_H1};
CTrade trade;    // Trading object
string EA_Name = "Multi-TF Gravestone Dragonfly EA";

// Function pointer type definition
typedef bool (*PatternCheckFunc)(ENUM_TIMEFRAMES timeframe, int shift);

MyPainel painel;
MyMagicNumber myMagicNumber;
//+------------------------------------------------------------------+
//| Check Gravestone Pattern                                         |
//+------------------------------------------------------------------+
bool IsGravestoneCandlestick(ENUM_TIMEFRAMES timeframe, int shift)
{
   double open = iOpen(_Symbol, timeframe, shift);
   double close = iClose(_Symbol, timeframe, shift);
   double high = iHigh(_Symbol, timeframe, shift);
   double low = iLow(_Symbol, timeframe, shift);
   
   return (high - MathMax(open, close) > (high - low) * 0.6) && 
          (MathAbs(open - close) < (high - low) * 0.1);
}

//+------------------------------------------------------------------+
//| Check Dragonfly Pattern                                         |
//+------------------------------------------------------------------+
bool IsDragonflyCandlestick(ENUM_TIMEFRAMES timeframe, int shift)
{
   double open = iOpen(_Symbol, timeframe, shift);
   double close = iClose(_Symbol, timeframe, shift);
   double high = iHigh(_Symbol, timeframe, shift);
   double low = iLow(_Symbol, timeframe, shift);
   
   return (MathMin(open, close) - low > (high - low) * 0.6) && 
          (MathAbs(open - close) < (high - low) * 0.1);
}

//+------------------------------------------------------------------+
//| Count pattern confirmations across timeframes                    |
//+------------------------------------------------------------------+
int CountPatternConfirmations(PatternCheckFunc checkFunction)
{
   int confirmations = 0;
   
   for(int i = 0; i < ArraySize(TimeFrames); i++)
   {
      for(int shift = 1; shift <= 3; shift++)
      {
         if(checkFunction((ENUM_TIMEFRAMES)TimeFrames[i], shift))
         {
            confirmations++;
            break;  // One confirmation per timeframe
         }
      }
   }
   
   return confirmations;
}

//+------------------------------------------------------------------+
//| Execute Trading Logic                                            |
//+------------------------------------------------------------------+
void ExecuteTrade(bool isBuy)
{
   double price, sl, tp;
   
   // Get point multiplier for correct SL/TP calculation
   double point = _Point * 10;
   
   if(isBuy)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - InpStopLoss * point;
      tp = price + InpTakeProfit * point;
      
      trade.Buy(InpLotSize, _Symbol, price, sl, tp, isBuy ? "Dragonfly Buy" : "Gravestone Sell");
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + InpStopLoss * point;
      tp = price - InpTakeProfit * point;
      
      trade.Sell(InpLotSize, _Symbol, price, sl, tp, isBuy ? "Dragonfly Buy" : "Gravestone Sell");
   }
   
   if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
   {
      Print("Trade error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check if we have open positions                                  |
//+------------------------------------------------------------------+
bool HasOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == myMagicNumber.magicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

   ulong magic =  myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),painel.getShortCurrencies());
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   
   // Initialize the trade object
   trade.SetExpertMagicNumber(magic);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(10); // Slippage
   
     EventSetTimer(1); 
   
   // Validate inputs
   if(InpLotSize <= 0 || InpStopLoss <= 0 || InpTakeProfit <= 0)
   {
      Print("Invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   return INIT_SUCCEEDED;
}

void OnTimer(){
   painel.OnTimer();
}
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   // Check if trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      return;
   }
   
   painel.OnTick();
   
   // Avoid multiple simultaneous positions
   if(HasOpenPositions())
   {
      return;
   }
   
   // Count confirmations
   int dragonflyConfirmations = CountPatternConfirmations(IsDragonflyCandlestick);
   int gravestoneConfirmations = CountPatternConfirmations(IsGravestoneCandlestick);
   
   // Multi Timeframe Trading Criteria
   if(dragonflyConfirmations >= 2)
   {
      ExecuteTrade(true);  // Buy
   }
   else if(gravestoneConfirmations >= 2)
   {
      ExecuteTrade(false);  // Sell
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

   painel.Destroy(reason);  
   
   EventKillTimer();
   
}