//+------------------------------------------------------------------+
//|                                      BOT_SUPORTE_RESISTENCIA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\CommonParams.mqh>
#include <.\MyMagicNumber.mqh>

input group "==== Params ====";
input  string starttime                 = "09:00:00";
input  string endtime                   = "24:00:00";
input  ENUM_TIMEFRAMES inputTimeFrame   = PERIOD_H1;
input  int  numberBarCheck              = 10; 

double priceHighest[], priceLoWest[];
double resitanceLevels[2],supportLevels[2];

#define resline "RESITANCE LEVEL";
#define colorRes clrRed;
#define res_line_prefix "R" 

#define supline "SUPPORT LEVEL";
#define colorSup clrBlue;
#define sup_line_prefix "S" 

MyPainel painel;
TraderInfos tradeInfos;
MyCtrader trade;
MyMagicNumber myMagicNumber;
string sep = ",";
string V_Currencies[];
int lenghtArray =0; 


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   
   ArraySetAsSeries(priceHighest,true);
   ArraySetAsSeries(priceLoWest,true);
   ArrayResize(priceHighest,50);   
   ArrayResize(priceLoWest,50);
   
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),painel.getShortCurrencies());
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   
   ushort sep_code = StringGetCharacter(sep,0);
   StringSplit(currencies,sep_code,V_Currencies);
   


   EventSetTimer(1);
   return(INIT_SUCCEEDED);
   
   
}
void OnDeinit(const int reason){
      
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
    for(int i=ArraySize(V_Currencies)-1;i>=0;i-- ){
      runBySymbol(V_Currencies[i]);  
   }
   
   
}
void OnTimer() {
    painel.OnTimer();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    painel.PanelChartEvent(id, lparam, dparam, sparam);
}


void runBySymbol(string symbol){
   

   double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE );

   string   DTstr  = TimeToString(TimeCurrent(), TIME_DATE);
   datetime start = StringToTime(DTstr + " " + starttime);
   datetime end    = StringToTime(DTstr + " " + endtime);
   
   int visibleBars = (int)  ChartGetInteger(0,CHART_VISIBLE_BARS);  //Bars(symbol,inputTimeFrame,start,end); //
   //Print("visibleBars",visibleBars);
   
   
   bool stop_processing = false;
   bool matchFound_high_1, matchFound_low_1 = false;
   bool matchFound_high_2, matchFound_low_2 = false;
   
   ArrayFree(priceHighest);
   ArrayFree(priceLoWest);
   
   int copiedBarsHighest = CopyHigh(symbol,inputTimeFrame,1,numberBarCheck,priceHighest);
   int copiedBarsLoWest  = CopyLow(symbol,inputTimeFrame,1,numberBarCheck,priceLoWest);
   
   ArraySort(priceHighest);
   ArraySort(priceLoWest);
   
   ArrayRemove(priceHighest,numberBarCheck,WHOLE_ARRAY);
   ArrayRemove(priceLoWest,0,visibleBars-10);
   
   for(int i = 1; i<=visibleBars-1 && !stop_processing  ;i++){
      //Print("::BAR NO: ",i);
      double open   =  iOpen(symbol,inputTimeFrame,i);
      double high   =  iHigh(symbol,inputTimeFrame,i);
      double low    =  iLow(symbol,inputTimeFrame,i);
      double close  =  iClose(symbol,inputTimeFrame,i);
      datetime time = iTime(symbol,inputTimeFrame,i);
      
      int diff_i_j = numberBarCheck;
      for(int j= i+diff_i_j;j<=visibleBars-1;j++){
         double open_j   =  iOpen(symbol,inputTimeFrame,j);
         double high_j   =  iHigh(symbol,inputTimeFrame,j);
         double low_j    =  iLow(symbol,inputTimeFrame,j);
         double close_j  =  iClose(symbol,inputTimeFrame,j);
         datetime time_j = iTime(symbol,inputTimeFrame,j);
         
         // CHECK FOR RESITENCE
         double high_diff  = NormalizeDouble(MathAbs((high-high_j)),0);
         //Print(_Digits);
         bool is_resitence = high_diff <=  numberBarCheck;
         
         // CHECK FOR SUPPORT
         double low_diff  = NormalizeDouble(MathAbs((low-low_j)),0);
         //Print("low_diff: "+low_diff);
         bool is_support = low_diff <=  numberBarCheck;
         
         if (is_resitence){
            //Print("RESISTENCE @BAR",i,"(",high,") & ",j,"(",high_j,") Pts =",high_diff);
            for (int k=0;k<ArraySize(priceHighest);k++){
                 matchFound_high_1 = priceHighest[k]==high;
                 matchFound_high_2 = priceHighest[k]==high_j;
                 if(matchFound_high_1 && matchFound_high_2 ){
                      if(resitanceLevels[0]==high || resitanceLevels[1]==high_j ){
                        stop_processing = true;
                        checkResitence(roundPriceH9K(high,price_step),symbol,visibleBars);
                        break;  
                      }else {
                        resitanceLevels[0]=high;
                        resitanceLevels[1]=high_j;
                        //draw_s_r_level(resline,high,colorRes,5)
                        //draw_s_r_level_point(sup_line_prefix,low,time,217,1,colorSup);
                        
                        stop_processing = true;
                        break;
                      } 
                 }   
            }
            
         }
         if (is_support){
            //Print("Suport @BAR",i,"(",high,") & ",j,"(",high_j,") Pts =",high_diff);
            for (int k=0;k<ArraySize(priceLoWest);k++){
                 matchFound_low_1 = priceLoWest[k]==low;
                 matchFound_low_2 = priceLoWest[k]==low_j;
                 if(matchFound_low_1 && matchFound_low_2 ){
                      if(supportLevels[0]==low || supportLevels[1]==low_j ){
                        stop_processing = true;
                        checkSuport(roundPriceH9K(high,price_step),symbol,visibleBars);
                        break;  
                      }else {
                        supportLevels[0]=low;
                        supportLevels[1]=low_j;
                        stop_processing = true;
                        
                        //draw_s_r_level(supline,low,colorSup,5);
                        //draw_s_r_level_point(sup_line_prefix,lw)
                        break;
                      } 
                 }   
            }
            
         }
         
         if (stop_processing){break;}
      }  
      if (stop_processing){break;}
   }

}

void draw_s_r_level(string levelName,double price,color clr,int width){
   if (ObjectFind(0,levelName)<0){
      ObjectCreate(0,levelName,OBJ_HLINE,0,TimeCurrent(),price);
      ObjectSetInteger(0,levelName,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,levelName,OBJPROP_WIDTH,width);
   }else{
      ObjectSetDouble(0,levelName,OBJPROP_PRICE,price);
   } 
   ChartRedraw(0);
}

void checkResitence(double price,string symbol, int visibleBars ){
   //Print("$$$$$ checkResitence "+ symbol);
   double visibleHighs[];
   static double resitencePrice = 0;
   ArraySetAsSeries(visibleHighs,true);
   CopyHigh(symbol,inputTimeFrame,1,visibleBars,visibleHighs);
   bool matchFound = false;
   for(int i = 0; i<ArraySize(visibleHighs);i++){
      if (visibleHighs[i]==price){
         matchFound = true;
         break;
      }
   
   }
   if (matchFound){
       Print("$$$$$ resitence found" + symbol);
      //if (resitencePrice != price){
         double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE );
         double ask  =  roundPriceH9K(SymbolInfoDouble(symbol, SYMBOL_ASK),price_step);
         double bid  =  roundPriceH9K(SymbolInfoDouble(symbol, SYMBOL_BID),price_step);
         
         double open         =  iOpen(symbol,inputTimeFrame,1);
         double high         =  iHigh(symbol,inputTimeFrame,1);
         double low          =  iLow(symbol,inputTimeFrame,1);
         double close        =  iClose(symbol,inputTimeFrame,1);
         datetime time       = iTime(symbol,inputTimeFrame,1);
         
         if (open> close && open < price && high > price 
            && bid <  price){
            Print("$$$$$ sell now signal "+ symbol);
            //usar o bid para vender
            double lots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;
            double entry_price  = SymbolInfoDouble(symbol, SYMBOL_BID);
            double sl           = roundPriceH9K(entry_price + (entry_price *iStopLossPercent /100),price_step);
            double tp           = roundPriceH9K(entry_price - (entry_price *iTakeProfitPercent /100) ,price_step);
            
            tradeInfos.lot_size        = lots;
            tradeInfos.amount          = entry_price;
            tradeInfos.order_type      = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
            tradeInfos.stop_loss       = sl; 
            tradeInfos.take_profit     = tp;
            tradeInfos.message         = MQLInfoString(MQL_PROGRAM_NAME)+ " " + symbol;
            trade.sendOrder(tradeInfos);
            
            resitencePrice = price;
         //}
      }
   }
}

void checkSuport(double price,string symbol, int visibleBars ){
   //Print("$$$$$ checkSuport "+ symbol);
   double visibleHighs[];
   static double resitencePrice = 0;
   ArraySetAsSeries(visibleHighs,true);
   CopyHigh(symbol,inputTimeFrame,1,visibleBars,visibleHighs);
   bool matchFound = false;
   for(int i = 0; i<ArraySize(visibleHighs);i++){
      if (visibleHighs[i]==price){
         matchFound = true;
         break;
      }
   
   }
   if (matchFound){
      Print("$$$$$ suport found "+ symbol);
      //if (resitencePrice != price){
         double lots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;
         double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE );
         double ask  =  roundPriceH9K(SymbolInfoDouble(symbol, SYMBOL_ASK),price_step);
         double bid  =  roundPriceH9K(SymbolInfoDouble(symbol, SYMBOL_BID),price_step);
         
         double open         =  iOpen(symbol,inputTimeFrame,1);
         double high         =  iHigh(symbol,inputTimeFrame,1);
         double low          =  iLow(symbol,inputTimeFrame,1);
         double close        =  iClose(symbol,inputTimeFrame,1);
         datetime time       = iTime(symbol,inputTimeFrame,1);
         
         if (open < close && open > price && low < price 
            && ask >  price){
            Print("$$$$$ buy now signal "+ symbol);
            //usar o ask para vender
            double entry_price  = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double sl           = roundPriceH9K(entry_price - (entry_price *iStopLossPercent /100),price_step);
            double tp           = roundPriceH9K(entry_price + (entry_price *iTakeProfitPercent /100) ,price_step);
            
            tradeInfos.lot_size = lots;
            tradeInfos.amount   = entry_price;
            tradeInfos.order_type = ORDER_TYPE_BUY;
            tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl; 
            tradeInfos.take_profit = tp; 
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ " " + symbol;
            trade.sendOrder(tradeInfos); 
            resitencePrice = price;
         }
     // }
   }
}

void draw_s_r_level_point(string objName,double price,datetime time,
                         int arrowcode,int direction ,color clr){

   StringConcatenate(objName,objName,"@ Time: ",time,"Price :",price);
   if (ObjectCreate(0,objName,OBJ_ARROW,0,time,price)){
      ObjectSetInteger(0,objName,OBJPROP_ARROWCODE,arrowcode);
      ObjectSetInteger(0,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,objName,OBJPROP_FONTSIZE,10);
      if(direction>0)  ObjectSetInteger(0,objName,OBJPROP_ANCHOR,ANCHOR_TOP);
      if(direction<0)  ObjectSetInteger(0,objName,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
   }
   string prefix = sup_line_prefix;
   string text = prefix + "("+ DoubleToString(price,_Digits); 
   string objNameDescr = objName+ text;
   if (ObjectCreate(0,objNameDescr,OBJ_TEXT,0,time,price)){
       ObjectSetInteger(0,objNameDescr,OBJPROP_COLOR,clr);
       ObjectSetInteger(0,objNameDescr,OBJPROP_FONTSIZE,10);
       //ObjectSetInteger(0,objNameDescr,OBJPROP_ANGLE,angle);
       ObjectSetString(0,objNameDescr,OBJPROP_TEXT,text);
      if(direction>0)  ObjectSetInteger(0,objNameDescr,OBJPROP_ANCHOR,ANCHOR_TOP);
      if(direction<0)  ObjectSetInteger(0,objNameDescr,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
   }
   ChartRedraw(0);

}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );

}

