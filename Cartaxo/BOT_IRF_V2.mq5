//+------------------------------------------------------------------+
//|                                                   BOT_MEDIAS.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rodrigo Cartaxo."
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>


//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input group "==== Params ====";
input const int                   iIFRPeriod       = 14;
input const ENUM_TIMEFRAMES       iIFRTimeFrame    = PERIOD_CURRENT;
input const ENUM_APPLIED_PRICE    iIFRAppliedPrice = PRICE_CLOSE;
input const int                   irRSILvel        = 100;


//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
MyPainel painel;
TraderInfos tradeInfos;
int ifrHandle;
double ifrBuffer[];
MyCtrader trade; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   if (!painel.OnInit())return INIT_FAILED ;

   ifrHandle = iRSI(_Symbol, iIFRTimeFrame, iIFRPeriod, iIFRAppliedPrice);
   if (ifrHandle == INVALID_HANDLE){
      Alert(" Failed to create  ifrHandle ");
      return (INIT_FAILED);
   };  
   
   ArraySetAsSeries(ifrBuffer, true);
    EventSetTimer(1);  

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
       
      if(ifrHandle!= INVALID_HANDLE  ){IndicatorRelease(ifrHandle);}  
      painel.Destroy(reason);  
      delete &tradeInfos;
      EventKillTimer();
   
 }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

      if (!isNewBar())return;
      
      painel.OnTick();
      
      int values =  CopyBuffer(ifrHandle,0,0,2,ifrBuffer);
      if (values!=2 ){
           Print("Fail to read ifrBuffer ");
           return; 
      }
      
      tradeInfos.iMagicNumber = iMagicNumber;
      tradeInfos.symbol = _Symbol; 
      double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE );
      
      
     
     if(ifrBuffer[1] >= (100-irRSILvel) && ifrBuffer[0] < (100-irRSILvel) && ( HasPosition(iMagicNumber) == 0) ){
     
         double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double sl  = roundPriceH9K(ask,price_step) - iStopLoss;   //* SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         double tp  = roundPriceH9K(ask,price_step) + iTakeProfit;// * SymbolInfoDouble(_Symbol,SYMBOL_POINT);     
         
         tradeInfos.lot_size = iAmount;
         tradeInfos.amount   = ask;
         tradeInfos.order_type = ORDER_TYPE_BUY;
         tradeInfos.stop_loss =sl; 
         tradeInfos.take_profit =tp; 
         tradeInfos.message = "IRF:"+_Symbol;
         trade.sendOrder(tradeInfos); 
          
     }else if(ifrBuffer[1] <= (100-irRSILvel) && ifrBuffer[0] > (irRSILvel) && ( HasPosition(iMagicNumber) == 0) ){
         
         double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double sl  = roundPriceH9K(bid,price_step) + iStopLoss ;  //* SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         double tp  = roundPriceH9K(bid,price_step) - iTakeProfit; //* SymbolInfoDouble(_Symbol,SYMBOL_POINT);  
         
         tradeInfos.lot_size        = iAmount;
         tradeInfos.amount          = bid;
         tradeInfos.order_type      = ORDER_TYPE_SELL;
         tradeInfos.stop_loss       = sl; 
         tradeInfos.take_profit     = tp;
         tradeInfos.message = "IRF:"+_Symbol;
         trade.sendOrder(tradeInfos);
     } 
     
    if ( HasPosition(iMagicNumber) != 0) trade.updateOrder();
      
     
     
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


