#property version "1.00"

#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>


input group "==== Params EMA ====";
input   int inputFastPeriodo            = 5;
input   int inputSlowPeriodo            = 10;
input   ENUM_TIMEFRAMES inputTimeFrame  = PERIOD_M5;  

input group "==== Params SAR ====";
input   ENUM_TIMEFRAMES inputSarRFrame  = PERIOD_M5; 
double  iStep                           = 0.02;
double  iMaximum                        = 0.2;


/*

 iSAR( 
   string           symbol,      // symbol name 
   ENUM_TIMEFRAMES  period,      // period 
   double           step,        // price increment step - acceleration factor 
   double           maximum      // maximum value of step 
*/

CTrade obj_Trade;
int fastHandle, slowHandle, handleSAR;
double fast_data[],slow_data[],sar_data[];


MyPainel painel;
TraderInfos tradeInfos;
MyCtrader trade;
MyMagicNumber myMagicNumber;

//+------------------------------------------------------------------+
//| Expert initialization function |
//+------------------------------------------------------------------+
int OnInit(){

   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),painel.getShortCurrencies());
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   
   string symbol = _Symbol;

   fastHandle = iMA(symbol,inputTimeFrame,inputFastPeriodo,0,MODE_SMA,PRICE_CLOSE);

   slowHandle = iMA(symbol,inputTimeFrame,inputSlowPeriodo,0,MODE_SMA,PRICE_CLOSE); 

   handleSAR = iSAR(symbol,inputSarRFrame,iStep,iMaximum);

   if (fastHandle==INVALID_HANDLE || slowHandle==INVALID_HANDLE || handleSAR==INVALID_HANDLE){
      Print("ERROR CREATING IND HANDLES. REVERTING NOW");
      return (INIT_FAILED);
   }
   
   ArraySetAsSeries(slow_data,true);
   ArraySetAsSeries(fast_data,true);
   ArraySetAsSeries(sar_data,true);
   EventSetTimer(1);  

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
      
      if(fastHandle!= INVALID_HANDLE  ){IndicatorRelease(fastHandle);}  
      if(slowHandle!= INVALID_HANDLE  ){IndicatorRelease(slowHandle);}  
      if(handleSAR!= INVALID_HANDLE  ){IndicatorRelease(handleSAR);}  
      painel.Destroy(reason);  
      delete &tradeInfos;
      EventKillTimer();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );
   
}
void OnTimer(){
   painel.OnTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function |
//+------------------------------------------------------------------+
void OnTick(){

   painel.OnTick();

   if (CopyBuffer(fastHandle,0,0,3,fast_data) < 3){
      Print("UNABLE TO COPY DATA FROM EMA 10 FOR FURTHER ANALYSIS. REVERTING");
      return;
   }
   if (CopyBuffer(slowHandle,0,0,3,slow_data) < 3){
      Print("UNABLE TO COPY DATA FROM EMA 20 FOR FURTHER ANALYSIS. REVERTING");
      return;
   }

   if (CopyBuffer(handleSAR,0,0,3,sar_data) < 3){
      Print("UNABLE TO COPY DATA FROM SAR 20  ANALYSIS. REVERTING");
      return;
   }
   
   datetime currBarTime = iTime(_Symbol,inputTimeFrame,0);
   static datetime signalTime = currBarTime;
   
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   
   double price_step = SymbolInfoDouble( _Symbol, SYMBOL_TRADE_TICK_SIZE );
   
   double low0 = iLow(_Symbol,inputTimeFrame,0);
   double high0 = iHigh(_Symbol,inputTimeFrame,0);
   tradeInfos.symbol = _Symbol;
   
   if (fast_data[0] > slow_data[0] && fast_data[1] < slow_data[1]
   && signalTime != currBarTime && sar_data[0] < low0){
      Print("BUY SIGNAL @ ",TimeCurrent());
      signalTime = currBarTime;
      if (HasPosition(myMagicNumber.magicNumber)==0){
         //obj_Trade.Buy(1,_Symbol,Ask,Ask-300*_Point,Ask+300*_Point, MQLInfoString(MQL_PROGRAM_NAME) + " " + _Symbol);
          //tradeInfos.lot_size = lots;
         tradeInfos.amount   =roundPriceH9K(Ask,price_step);
         tradeInfos.order_type = ORDER_TYPE_BUY;
         tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
         tradeInfos.stop_loss = roundPriceH9K(Ask-300*_Point,price_step); 
         tradeInfos.take_profit = roundPriceH9K(Ask+300*_Point,price_step); 
         tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + _Symbol;
         trade.sendOrder(tradeInfos); 
    }
   }
   else if (fast_data[0] < slow_data[0] && fast_data[1] > slow_data[1]
   && signalTime != currBarTime && sar_data[0] > low0){
      Print("SELL SIGNAL @ ",TimeCurrent());
      signalTime = currBarTime;
      if (HasPosition(myMagicNumber.magicNumber)==0){
         //obj_Trade.Sell(1,_Symbol,Bid,Bid+300*_Point,Bid-300*_Point, MQLInfoString(MQL_PROGRAM_NAME) + " " + _Symbol);
          tradeInfos.amount   = roundPriceH9K(Bid,price_step);
         tradeInfos.order_type = ORDER_TYPE_BUY;
         tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
         tradeInfos.stop_loss = roundPriceH9K(Bid+300*_Point,price_step); 
         tradeInfos.take_profit = roundPriceH9K(Bid-300*_Point,price_step); 
         tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + _Symbol;
         trade.sendOrder(tradeInfos); 
         
      }
   }
}
