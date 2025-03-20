//+------------------------------------------------------------------+
//|                                               BOT_TIME_RANGE.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rodrigo Cartaxo."
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input const int iRangeSart = 600;
input const int iRangeDuration = 120;
input const int iRangeClose = 1200;
input const double iAmount = 0.01;
input const ulong iMagicNumber = 526363;
input const int iStopLoss = 150;
input const int iTakeProfit = 200;

enum BREAKOUT_MODE{
   ONE_SIGNALS,
   TWO_SIGNALS
};

input const BREAKOUT_MODE IBreakOutMode = ONE_SIGNALS;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+

struct RANGRE_STRUCT{ 
   datetime start_time;   
   datetime end_time;
   datetime close_time;
   double high;
   double low;
   bool f_entry;
   bool f_high_breakout;
   bool f_low_breakout;
   
   RANGRE_STRUCT():start_time(0),end_time(0),close_time(0),high(0),low(DBL_MAX),
   f_entry(false),f_high_breakout(false),f_low_breakout(false){};
   


}; 
RANGRE_STRUCT range;
MqlTick prevTick, lasTick;
CTrade ctrade;



int OnInit(){

    ctrade.SetExpertMagicNumber(iMagicNumber);
    if(HasPosition(iMagicNumber)==0){ 
         CalculateRange(); 
    };
  
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
 ObjectDelete(NULL,"range");
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
      
      
      prevTick = lasTick;
      SymbolInfoTick(_Symbol,lasTick);
      
      if (lasTick.time >= range.start_time && lasTick.time < range.end_time ){
         range.f_entry = true;
         if (lasTick.ask>range.high){
            range.high = lasTick.ask;
            DrawObjects();
         }
         if (lasTick.bid>range.low){
            range.low = lasTick.bid;
            DrawObjects();
         }
      }

      if(lasTick.time>= range.close_time ){
         closeAllPositions(ctrade,iMagicNumber);
         
      
      } 
      
      if ((iRangeClose >=0 && lasTick.time>range.close_time)
         || (range.f_high_breakout && range.f_low_breakout)
         || range.end_time==0 
         || (range.end_time!=0 && lasTick.time > range.end_time && !range.f_entry)
         || HasPosition(iMagicNumber)==0) {
         }
         
         
     CheckBreakouts();             
          
  }


void CheckBreakouts(){
   
   if (lasTick.time>= range.end_time && range.end_time >0 && range.f_entry ){
      if(!range.f_high_breakout && lasTick.ask >= range.high  ){
         range.f_high_breakout = true;
         if (IBreakOutMode == ONE_SIGNALS){range.f_low_breakout= true;}
         
         double sl = NormalizeDouble(lasTick.bid - ((range.high-range.low )*iStopLoss * 0.01),_Digits);
         double tp = NormalizeDouble(lasTick.bid + ((range.high-range.low )*iTakeProfit * 0.01),_Digits);
                 
         ctrade.PositionOpen(_Symbol,ORDER_TYPE_BUY,iAmount,lasTick.ask,sl,tp,"Time Ragne EA "+ _Symbol);
         
      }
      if(!range.f_low_breakout && lasTick.bid <= range.low){
         range.f_low_breakout = true;
         if (IBreakOutMode == ONE_SIGNALS){range.f_high_breakout= true;}

         double sl = NormalizeDouble(lasTick.ask + ((range.high-range.low )*iStopLoss * 0.01),_Digits);
         double tp = NormalizeDouble(lasTick.ask - ((range.high-range.low )*iTakeProfit * 0.01),_Digits);
         
         ctrade.PositionOpen(_Symbol,ORDER_TYPE_SELL,iAmount,lasTick.bid,sl,tp,"Time Ragne EA "+ _Symbol);
         
      }
      
   }

}

void CalculateRange(){
   
   range.start_time = 0;
   range.end_time = 0;
   range.close_time = 0;
   range.high = 0.0;
   range.low = DBL_MAX;
   range.f_entry = false;
   range.f_high_breakout = false;
   range.f_low_breakout = false;
   

   // caculate range start time
   int time_cycle = 86400;
   range.start_time = (lasTick.time -(lasTick.time % time_cycle ) )+ iRangeSart *60;
   for(int i = 0;i<8;i++){
      MqlDateTime tmp;
      TimeToStruct(range.start_time,tmp);
      int dow = tmp.day_of_week;
      if (lasTick.time > range.start_time || dow == 6 || dow ==0 ){
            range.start_time+=time_cycle;     
      }
   } 
   
   // caculate range end time
   range.end_time = range.start_time + iRangeDuration *60;
   for(int i = 0;i<2;i++){
      MqlDateTime tmp;
      TimeToStruct(range.end_time,tmp);
      int dow = tmp.day_of_week;
      if (dow == 6 || dow ==0 ){
            range.end_time+=time_cycle;     
      }
   }
   
   // caculate range close time
  range.close_time = (range.end_time -(range.end_time % time_cycle ) )+ iRangeClose *60;
   for(int i = 0;i<3;i++){
      MqlDateTime tmp;
      TimeToStruct(range.close_time,tmp);
      int dow = tmp.day_of_week;
      if (range.close_time > range.end_time || dow == 6 || dow ==0 ){
            range.close_time+=time_cycle;     
      }
   }
   
   DrawObjects(); 
}   
  
void DrawObjects(){
   
   // start time
   ObjectDelete(NULL,"range start");
   if (range.start_time >0){
      ObjectCreate(NULL,"range start",OBJ_VLINE,0,range.start_time,0);
      ObjectSetString(NULL,"range start",OBJPROP_TOOLTIP,"start of range \n"+TimeToString(range.start_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,"range start",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range start",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range start",OBJPROP_BACK,true);
   
   }
   // end time
   ObjectDelete(NULL,"range end");
   if (range.end_time >0){
      ObjectCreate(NULL,"range end",OBJ_VLINE,0,range.end_time,0);
      ObjectSetString(NULL,"range end",OBJPROP_TOOLTIP,"end of range \n"+TimeToString(range.end_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,"range end",OBJPROP_COLOR,clrDarkBlue);
      ObjectSetInteger(NULL,"range end",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range end",OBJPROP_BACK,true);
   
   }
   // close time
   ObjectDelete(NULL,"range close");
   if (range.close_time >0){
      ObjectCreate(NULL,"range close",OBJ_VLINE,0,range.close_time,0);
      ObjectSetString(NULL,"range close",OBJPROP_TOOLTIP,"close of range \n"+TimeToString(range.close_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,"range close",OBJPROP_COLOR,clrRed);
      ObjectSetInteger(NULL,"range close",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range close",OBJPROP_BACK,true);
   
   }
   // high time
   ObjectsDeleteAll(NULL,"range high");
   if (range.high >0){
      ObjectCreate(NULL,"range high",OBJ_TREND,0,range.start_time,range.high,range.end_time,range.high);
      ObjectSetString(NULL,"range high",OBJPROP_TOOLTIP,"high of range \n"+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,"range high",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range high",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range high",OBJPROP_BACK,true);
      
     
      ObjectCreate(NULL,"range high",OBJ_TREND,0,range.start_time,range.high,range.close_time,range.high);
      ObjectSetString(NULL,"range high",OBJPROP_TOOLTIP,"high of range \n"+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,"range high",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range high",OBJPROP_BACK,true);
      ObjectSetInteger(NULL,"range high",OBJPROP_STYLE,STYLE_DOT);
   
   }  
   
   // low time
   ObjectsDeleteAll(NULL,"range low");
   if (range.high >99999999){
      ObjectCreate(NULL,"range low",OBJ_TREND,0,range.start_time,range.low,range.end_time,range.low);
      ObjectSetString(NULL,"range low",OBJPROP_TOOLTIP,"low of range \n"+DoubleToString(range.low,_Digits));
      ObjectSetInteger(NULL,"range low",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range low",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range low",OBJPROP_BACK,true);
      
     
      ObjectCreate(NULL,"range low",OBJ_TREND,0,range.start_time,range.low,range.close_time,range.low);
      ObjectSetString(NULL,"range low",OBJPROP_TOOLTIP,"low of range \n"+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,"range low",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range low",OBJPROP_BACK,true);
      ObjectSetInteger(NULL,"range low",OBJPROP_STYLE,STYLE_DOT);
   
   
   }         
  
  
} 


    


