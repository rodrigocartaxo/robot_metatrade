//+------------------------------------------------------------------+
//|                                            BOT_SILVER_BULLET.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <trade\trade.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>


class CFairValueGap :public CObject{
   
   public:
      int direction;
      datetime time;
      double high;
      double low;
      
      void draw (datetime timeStart , datetime timeEnd ){
         string objFvg = "SB FGV" + TimeToString(time);
         ObjectCreate(0,objFvg,OBJ_RECTANGLE,0,time,low,timeStart,high);
         ObjectSetInteger(0,objFvg,OBJPROP_FILL,true);
         ObjectSetInteger(0,objFvg,OBJPROP_COLOR,clrLightGray);
         
         string objTrade = "SB Trade" + TimeToString(time);
         ObjectCreate(0,objFvg,OBJ_RECTANGLE,0,timeStart,low,timeEnd,high);
         ObjectSetInteger(0,objFvg,OBJPROP_FILL,true);
         ObjectSetInteger(0,objFvg,OBJPROP_COLOR,clrGray);
      }
      
     void drawTradeLevels(double tp , double sl, datetime timeStart, datetime timeEnd){
         string objTP = "SB TP" + TimeToString(time);
         ObjectCreate(0,objTP,OBJ_RECTANGLE,0,timeStart,(direction >0 ?high:low) ,timeEnd,tp);
         ObjectSetInteger(0,objTP,OBJPROP_FILL,true);
         ObjectSetInteger(0,objTP,OBJPROP_COLOR,clrLightGreen);
         
         string objSL = "SB SL" + TimeToString(time);
         ObjectCreate(0,objSL,OBJ_RECTANGLE,0,timeStart,(direction >0 ?high:low) ,timeEnd,sl);
         ObjectSetInteger(0,objSL,OBJPROP_FILL,true);
         ObjectSetInteger(0,objSL,OBJPROP_COLOR,clrOrange);
         
         
     
     }

};

input int MinFvgPoints   = 10;
input int timeStartHour  = 9;
input int timeEndHour    = 18;

CFairValueGap* fvg;
MyPainel painel;
TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;
MyCtrader trade;

int OnInit(){
 
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),currencies);
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   
   EventSetTimer(1);  
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   ObjectsDeleteAll(0,"SB");
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


void OnTick(){

   //painel.OnTick();
   
   static int lastDay = 0 ;
   MqlDateTime structTime;
   TimeCurrent(structTime);
   structTime.min = 0;
   structTime.sec = 0;         
   
   structTime.hour = timeStartHour;
   datetime timeStart = StructToTime(structTime);
   
   structTime.hour = timeEndHour;
   datetime timeEnd = StructToTime(structTime);
   string symbol = Symbol();
   double points = SymbolInfoDouble(symbol, SYMBOL_POINT);   
   
   if (TimeCurrent() >= timeStart &&  TimeCurrent() < timeEnd  ){
      if (lastDay!= structTime.day_of_year){
         delete fvg;
         for(int i= 1; i<100;i++ ){
            if(iLow(symbol,iTradeTimeFrame,i)-iHigh(symbol,iTradeTimeFrame,i+2) >MinFvgPoints * points){
               fvg = new CFairValueGap();
               fvg.direction = 1;
               fvg.time = iTime(symbol,iTradeTimeFrame,i+1);
               fvg.high = iLow(symbol,iTradeTimeFrame,i);
               fvg.low = iHigh(symbol,iTradeTimeFrame,i+2);
               
               if (iLow(symbol,iTradeTimeFrame,iLowest(symbol,iTradeTimeFrame,MODE_LOW,i+1))<= fvg.low){
                  delete fvg;
                  break;                  
               } 
               fvg.draw(timeStart,timeEnd);
               lastDay = structTime.day_of_year;
               break;               
               
            }
            if(iLow(symbol,iTradeTimeFrame,i+2)-iHigh(symbol,iTradeTimeFrame,i) >MinFvgPoints * points){
               fvg = new CFairValueGap();
               fvg.direction = -1;
               fvg.time = iTime(symbol,iTradeTimeFrame,i+1);
               fvg.high = iLow(symbol,iTradeTimeFrame,i+2);
               fvg.low = iHigh(symbol,iTradeTimeFrame,i);
               if (iHigh(symbol,iTradeTimeFrame,iHighest(symbol,iTradeTimeFrame,MODE_HIGH,i+1))>= fvg.high){
                  delete fvg;
                  break;                  
               } 
               fvg.draw(timeStart,timeEnd);
               lastDay = structTime.day_of_year;
               break;  
            }
         
         }
         
      }
      
        double ask  = SymbolInfoDouble(symbol, SYMBOL_ASK);   
        double bid  = SymbolInfoDouble(symbol, SYMBOL_BID); 
        double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE );
        
        double lots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;
        
        tradeInfos.symbol = symbol; 
        
        if(CheckPointer(fvg)!= POINTER_INVALID && fvg.direction > 0 && ask < fvg.high  ){
          double entry_price  = ask;
          double sl           = roundPriceH9K(iLow(symbol,iTradeTimeFrame,iLowest(symbol,iTradeTimeFrame,MODE_LOW,5,iBarShift(symbol,iTradeTimeFrame,fvg.time))),price_step);
          double tp           = roundPriceH9K(iHigh(symbol,iTradeTimeFrame,iHighest(symbol,iTradeTimeFrame,MODE_HIGH,iBarShift(symbol,iTradeTimeFrame,fvg.time))),price_step);
          
          fvg.drawTradeLevels(tp,sl,timeStart,timeEnd);
          
          double minTP=  (entry_price *iTakeProfitPercent /100)*points;
          
          if (tp - entry_price > minTP   ){
               tradeInfos.lot_size = lots;
               tradeInfos.amount   = entry_price;
               tradeInfos.order_type = ORDER_TYPE_BUY;
               tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
               tradeInfos.stop_loss =sl; 
               tradeInfos.take_profit =tp; 
               tradeInfos.message =  MQLInfoString(MQL_PROGRAM_NAME)+":"+ symbol;
               trade.sendOrder(tradeInfos); 
              Print(__FUNCTION__ ">Buy signal ");
              
          }
          
        delete fvg;
        } 
        if(CheckPointer(fvg)!= POINTER_INVALID && fvg.direction < 0 && bid > fvg.low  ){
          double entry_price  = bid;
          double tp           = roundPriceH9K(iLow(symbol,iTradeTimeFrame,iLowest(symbol,iTradeTimeFrame,MODE_LOW,iBarShift(symbol,iTradeTimeFrame,fvg.time))),price_step);
          double sl           = roundPriceH9K(iHigh(symbol,iTradeTimeFrame,iHighest(symbol,iTradeTimeFrame,MODE_HIGH,5,iBarShift(symbol,iTradeTimeFrame,fvg.time))),price_step);
       
          
          fvg.drawTradeLevels(tp,sl,timeStart,timeEnd);
          
          double minTP=  (entry_price *iTakeProfitPercent /100)*points;
          
          if (entry_price -  tp   > minTP   ){
            tradeInfos.lot_size = lots;
            tradeInfos.amount   = entry_price;
            tradeInfos.order_type = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
            tradeInfos.stop_loss =sl; 
            tradeInfos.take_profit =tp; 
            tradeInfos.message =  MQLInfoString(MQL_PROGRAM_NAME)+":"+symbol;
            trade.sendOrder(tradeInfos); 
              Print(__FUNCTION__ ">Sell signal ");
            
          }
          delete fvg;
        } 
          
      
   }
   
   
  }

