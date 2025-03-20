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
input const int inputFastPeriodo            = 5;
input const int inputSlowPeriodo            = 10;
input const ENUM_TIMEFRAMES inputTimeFrame  = PERIOD_M5;    

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
MyPainel painel;
TraderInfos tradeInfos;
int fastHandle;
int slowHandle;
double fastBuffer[];
double slowBuffer[];
MyCtrader trade; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   if (!painel.OnInit())return INIT_FAILED ;

   fastHandle = iMA(_Symbol,inputTimeFrame,inputFastPeriodo,0,MODE_SMA,PRICE_CLOSE);
   if (fastHandle == INVALID_HANDLE){
      Alert(" Failed to create fast Handle ");
   };  
   slowHandle = iMA(_Symbol,inputTimeFrame,inputSlowPeriodo,0,MODE_SMA,PRICE_CLOSE); 
   if (slowHandle == INVALID_HANDLE){
      Alert(" Failed to create slow Handle ");
   };   
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true); 
   EventSetTimer(1);    

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
      
      EventKillTimer();
      if(fastHandle!= INVALID_HANDLE  ){IndicatorRelease(fastHandle);}  
      if(slowHandle!= INVALID_HANDLE  ){IndicatorRelease(slowHandle);}
      painel.Destroy(reason);  
      delete &tradeInfos;
      EventKillTimer();
   
 }
 void OnTimer(){
 
   painel.OnTimer();
 }
 
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

      if (!isNewBar())return;
      
      painel.OnTick();
      
      int values =  CopyBuffer(fastHandle,0,0,2,fastBuffer);
      if (values!=2 ){
           Print("Fail to read fastHandle ");
           return; 
      }
       
      values = CopyBuffer(slowHandle,0,0,2,slowBuffer);
      if (values!=2 ){
           Print("Fail to read fastHandle ");
           return; 
      }
      
      
      tradeInfos.iMagicNumber = iMagicNumber;
      tradeInfos.symbol = _Symbol; 
      double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE );
      
      
     
     if(fastBuffer[1]<= slowBuffer[1] && fastBuffer[0]>slowBuffer[0] && ( HasPosition(iMagicNumber) == 0) ){
     
         double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double sl  = roundPriceH9K(ask,price_step) - iStopLoss;   //* SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         double tp  = roundPriceH9K(ask,price_step) + iTakeProfit;// * SymbolInfoDouble(_Symbol,SYMBOL_POINT);     
         
         tradeInfos.lot_size = iAmount;
         tradeInfos.amount   = ask;
         tradeInfos.order_type = ORDER_TYPE_BUY;
         tradeInfos.stop_loss =sl; 
         tradeInfos.take_profit =tp; 
         tradeInfos.message = "Bot Medias" + _Symbol;
         trade.sendOrder(tradeInfos); 
          
     }else if(fastBuffer[1]>= slowBuffer[1] && fastBuffer[0]<slowBuffer[0] && ( HasPosition(iMagicNumber) == 0) ){
         
         double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double sl  = roundPriceH9K(bid,price_step) + iStopLoss ;  //* SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         double tp  = roundPriceH9K(bid,price_step) - iTakeProfit; //* SymbolInfoDouble(_Symbol,SYMBOL_POINT);  
         
         tradeInfos.lot_size        = iAmount;
         tradeInfos.amount          = bid;
         tradeInfos.order_type      = ORDER_TYPE_SELL;
         tradeInfos.stop_loss       = sl; 
         tradeInfos.take_profit     = tp;
         tradeInfos.message = "Bot Medias" + _Symbol;
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


