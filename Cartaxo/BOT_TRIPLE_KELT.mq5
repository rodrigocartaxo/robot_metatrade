//+------------------------------------------------------------------+
//|                                                     BOT_KELT.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>
#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>


input group "==== Params Kelt 1  ====";
input ENUM_TIMEFRAMES       iKeltimeFrame          = PERIOD_M5;
input int                   iKeltEmaPerid          = 20;
input int                   iKeltAtrPerid          = 10;
input double                iKeltMulti             = 2.0;
input group "==== Params Kelt 2  ====";
input ENUM_TIMEFRAMES       iKeltimeFrame2          = PERIOD_M5;
input int                   iKeltEmaPerid2          = 20;
input int                   iKeltAtrPerid2          = 10;
input double                iKeltMulti2             = 3.0;
input group "==== Params Kelt 3  ====";
input ENUM_TIMEFRAMES       iKeltimeFrame3          = PERIOD_M5;
input int                   iKeltEmaPerid3          = 20;
input int                   iKeltAtrPerid3          = 10;
input double                iKeltMulti3             = 4.0;


input group "==== Params SMA ====";
input int inputFastPeriodo = 5;
input int inputSlowPeriodo = 10;
input ENUM_TIMEFRAMES inputTimeFrame = PERIOD_M5;


int handle_keltner_1;
int handle_keltner_2;
int handle_keltner_3;
int handle_sma;

double upper_1[], lower_1[],upper_2[], lower_2[],upper_3[], lower_3[],sma[];


datetime timestamp; 
MyPainel painel;
TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;
MyCtrader trade;



struct SIndicators{
   
   int keltner_1;
   int keltner_2;
   int keltner_3;
   int sma;
   string symbol;
};


SIndicators vSIndicators[];
MqlRates rates[];

int OnInit(){
  
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),currencies);
   
   if (!painel.OnInit(myMagicNumber.magicNumber)) Alert ("Error on init magicNumber ") ;
      
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ushort sep_code = StringGetCharacter(sep,0);
   int lenghtArray = StringSplit(currencies,sep_code,V_Currencies);
   ArrayResize(vSIndicators,lenghtArray);
  
   ArraySetAsSeries(upper_1, true);
   ArraySetAsSeries(lower_1, true);
   ArraySetAsSeries(upper_2, true);
   ArraySetAsSeries(lower_2, true);
   ArraySetAsSeries(upper_3, true);
   ArraySetAsSeries(lower_3, true);
   ArraySetAsSeries(sma, true);
   ArraySetAsSeries(rates, true);
  
   for(int i=lenghtArray-1;i>=0;i-- ){
       vSIndicators[i]=  initIndicators(V_Currencies[i]);  
   }

   EventSetTimer(1);   
  

   return INIT_SUCCEEDED;
}   
SIndicators initIndicators(string symbol){
   SIndicators s;
   
  
   handle_keltner_1 = iCustom(symbol, iKeltimeFrame, "Free Indicators\\Keltner Channel", iKeltEmaPerid,iKeltAtrPerid,iKeltMulti,false);
   handle_keltner_2 = iCustom(symbol, iKeltimeFrame2, "Free Indicators\\Keltner Channel", iKeltEmaPerid2,iKeltAtrPerid2,iKeltMulti2,false);
   handle_keltner_3 = iCustom(symbol, iKeltimeFrame3, "Free Indicators\\Keltner Channel", iKeltEmaPerid3,iKeltAtrPerid3,iKeltMulti3,false);
   
   
   
   if (handle_keltner_1 == INVALID_HANDLE || 
      handle_keltner_2 == INVALID_HANDLE  ||
      handle_keltner_3 == INVALID_HANDLE ){
      Alert("Erro ao criar o handle do indicador!"+  symbol);
      
   }
   
   handle_sma = iMA(symbol, inputTimeFrame, inputFastPeriodo, 0, MODE_SMA, PRICE_CLOSE);
   
   if(handle_sma == INVALID_HANDLE) {
        Print("Erro crítico: Falha ao criar handle EMA rápida para ", symbol);
        return s;
    }
   s.keltner_1 = handle_keltner_1;
   s.keltner_2 = handle_keltner_2;
   s.keltner_3 = handle_keltner_3;
   s.sma = handle_sma;
   s.symbol = symbol;
   
  return s;
  
  
}


   
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   
   if(handle_keltner_1!= INVALID_HANDLE ){IndicatorRelease(handle_keltner_1);}  
   if(handle_keltner_2!= INVALID_HANDLE ){IndicatorRelease(handle_keltner_2);}  
   if(handle_keltner_3!= INVALID_HANDLE ){IndicatorRelease(handle_keltner_3);}  
   if(handle_sma!= INVALID_HANDLE ){IndicatorRelease(handle_sma);}  
   
   painel.Destroy(reason);  
   delete &tradeInfos;
   EventKillTimer();
   
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
      
  for(int i=ArraySize(V_Currencies)-1;i>=0;i-- ){
      SIndicators indic =   vSIndicators[i];
      
         
      datetime time0 = iTime(indic.symbol,iTradeTimeFrame,0);
         
      if (timestamp != time0){
            timestamp = time0;
            painel.OnTick(); 
             
      if (CopyBuffer(indic.keltner_1, 0, 1, 2, upper_1) <= 0 ||
          CopyBuffer(indic.keltner_1, 2, 1, 2, lower_1) <= 0 ){
          Print("Erro ao copiar os buffers do indicador!");
          return;
      }
      if (CopyBuffer(indic.keltner_2, 0, 1, 2, upper_2) <= 0 ||
          CopyBuffer(indic.keltner_2, 2, 1, 2, lower_2) <= 0 ){
          Print("Erro ao copiar os buffers do indicador!");
          return;
      }
      if (CopyBuffer(indic.keltner_3, 0, 1, 2, upper_3) <= 0 ||
          CopyBuffer(indic.keltner_3, 2, 1, 2, lower_3) <= 0 ){
          Print("Erro ao copiar os buffers do indicador!");
          return;
      }
      if (CopyBuffer(indic.sma, 0, 0, 2, sma) != 2){  
          Print("Erro ao copiar os buffers do indicador!");
          return;
      }       
  
      int copied  = CopyRates(indic.symbol, inputTimeFrame, 0, 3, rates);
      if(copied <= 0) return; 
      
      
      
      double lots = SymbolInfoDouble(indic.symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;       
      double price_step = SymbolInfoDouble(indic.symbol, SYMBOL_TRADE_TICK_SIZE );
     
      tradeInfos.symbol = indic.symbol;
      
      
      
      if (HasPosition(tradeInfos.iMagicNumber) == 0 && rates[1].close <= upper_1[1] && rates[1].close >= lower_1[1]){
            if (rates[0].close <= lower_1[0]){
                double entry_price = SymbolInfoDouble(indic.symbol, SYMBOL_ASK);
                double sl = roundPriceH9K(entry_price - (entry_price * iStopLossPercent/100), price_step);
                double tp = roundPriceH9K(entry_price + (entry_price * iTakeProfitPercent/100), price_step);
                
                tradeInfos.amount = entry_price;
                tradeInfos.order_type = ORDER_TYPE_BUY;
                tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
                tradeInfos.stop_loss = sl;
                tradeInfos.take_profit = tp;
                tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + indic.symbol;
                trade.sendOrder(tradeInfos);
               
            }
      }else if (HasPosition(tradeInfos.iMagicNumber) == 0 && rates[1].close <= upper_1[1] && rates[1].close >= lower_1[1]){
               if (rates[0].close >= upper_1[0]){
                
                double entry_price = SymbolInfoDouble(indic.symbol, SYMBOL_BID);
                double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent/100), price_step);
                double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent/100), price_step);
                
                tradeInfos.amount = entry_price;
                tradeInfos.order_type = ORDER_TYPE_SELL;
                tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
                tradeInfos.stop_loss = sl;
                tradeInfos.take_profit = tp;
                tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + indic.symbol;
                trade.sendOrder(tradeInfos);
            }
      }
          
     
      //Print("price_step",price_step) ;
      //Print("symbol",indic.symbol) ;
     
      //int digits 
      
      
     
      /*bool isBuyContra= (middle[1] > middle[0] ) && (close1 > lower[1] && close2 < lower[0] );
      bool isBuyAFavor= (close1 < lower[0] && close0 > lower[0]);
      
      tradeInfos.symbol = indic.symbol; 
      if ( isBuyContra    && HasPosition(myMagicNumber.magicNumber) == 0)  {
         
          double entry_price  = SymbolInfoDouble(indic.symbol, SYMBOL_ASK);
          double sl           = roundPriceH9K(entry_price - (entry_price *iStopLossPercent /100),price_step);
          //NormalizeDouble()
          double tp           = roundPriceH9K(entry_price + (entry_price *iTakeProfitPercent /100) ,price_step);
      
          tradeInfos.lot_size = lots;
          tradeInfos.amount   = entry_price;
          tradeInfos.order_type = ORDER_TYPE_BUY;
          tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
          tradeInfos.stop_loss =sl; 
          tradeInfos.take_profit =tp; 
          tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ ": "+ indic.symbol;
          trade.sendOrder(tradeInfos); 
         
        }
      
      
      bool isSellContra  = (middle[1] < middle[0] ) &&(close1 < upper[1] && close2 > upper[0] );
      bool isSellAFavor  = (close1 > upper[0] && close0 < upper[0]) ;
      
      
      if (isSellContra     &&  HasPosition(myMagicNumber.magicNumber,indic.symbol) == 0){
         
       double entry_price  = SymbolInfoDouble(indic.symbol, SYMBOL_BID);
       double sl           = roundPriceH9K(entry_price + (entry_price *iStopLossPercent /100),price_step);
       double tp           = roundPriceH9K(entry_price - (entry_price *iTakeProfitPercent /100) ,price_step);
                  
       tradeInfos.lot_size = lots;
       tradeInfos.amount   = entry_price;
       tradeInfos.order_type = ORDER_TYPE_SELL;
       tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
       tradeInfos.stop_loss =sl; 
       tradeInfos.take_profit =tp; 
       tradeInfos.message =  MQLInfoString(MQL_PROGRAM_NAME) + ": "+ indic.symbol;
       trade.sendOrder(tradeInfos); 
         
         }*/
      }
    }
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
