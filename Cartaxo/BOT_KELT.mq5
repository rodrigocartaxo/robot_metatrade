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
#include <.\Personal\\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>




input group "==== Params ====";
input ENUM_TIMEFRAMES       iKeltimeFrame          = PERIOD_M5;
input int                   iKeltEmaPerid          = 20;
input int                   iKeltAtrPerid          = 10;
input double                iKeltMulti             = 2.0;


int handle_keltner;

double upper[], middle[], lower[];

datetime timestamp; 
MyPainel painel;
TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;
MyCtrader trade;

string sep = ",";
string V_Currencies[];
int lenghtArray =0; 

struct SIndicators{
   
   int keltner;
   string symbol;
};


SIndicators vSIndicators[];

int OnInit(){
  
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),currencies);
   
   if (!painel.OnInit(myMagicNumber.magicNumber)) Alert ("Error on init magicNumber ") ;
      
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ushort sep_code = StringGetCharacter(sep,0);
   lenghtArray = StringSplit(currencies,sep_code,V_Currencies);
   ArrayResize(vSIndicators,lenghtArray);
  
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(middle, true);
   ArraySetAsSeries(lower, true);
  
   for(int i=lenghtArray-1;i>=0;i-- ){
       vSIndicators[i]=  initIndicators(V_Currencies[i]);  
   }

   EventSetTimer(1);   
  

   return INIT_SUCCEEDED;
}   
SIndicators initIndicators(string symbol){
   SIndicators s;
   
  
   handle_keltner = iCustom(symbol, iKeltimeFrame, "Free Indicators\\Keltner Channel", iKeltEmaPerid,iKeltAtrPerid,iKeltMulti,false);

   s.keltner = handle_keltner;
   s.symbol = symbol;
                           
                           
   if (handle_keltner == INVALID_HANDLE){
      Alert("Erro ao criar o handle do indicador!"+  symbol);
      
  }
  
 
  return s;
  
  
}


   
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   
   if(handle_keltner!= INVALID_HANDLE ){IndicatorRelease(handle_keltner);}  
   
   painel.Destroy(reason);  
   delete &tradeInfos;
   EventKillTimer();
   
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
      
  for(int i=lenghtArray-1;i>=0;i-- ){
      SIndicators indic =   vSIndicators[i];
      
         
      datetime time0 = iTime(indic.symbol,iTradeTimeFrame,0);
         
      if (timestamp != time0){
            timestamp = time0;
            painel.OnTick(); 
             
      if (CopyBuffer(indic.keltner, 0, 1, 2, upper) <= 0 ||
          CopyBuffer(indic.keltner, 1, 1, 2, middle) <= 0 ||
          CopyBuffer(indic.keltner, 2, 1, 2, lower) <= 0 ){
          Print("Erro ao copiar os buffers do indicador!");
          return;
      }     
  
      double close0 = iClose(indic.symbol,iTradeTimeFrame,0);
      double close1 = iClose(indic.symbol,iTradeTimeFrame,1);
      double close2 = iClose(indic.symbol,iTradeTimeFrame,2);
      
      double lots = SymbolInfoDouble(indic.symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;
       
      double price_step = SymbolInfoDouble(indic.symbol, SYMBOL_TRADE_TICK_SIZE );
     // Print("price_step",price_step) ;
      //Print("symbol",indic.symbol) ;
     
      //int digits 
     
      bool isBuyContra= (middle[1] > middle[0] ) && (close1 > lower[1] && close2 < lower[0] );
      bool isBuyAFavor= (close1 < lower[0] && close0 > lower[0]);
      
      tradeInfos.symbol = indic.symbol; 
      if ( isBuyContra    && HasPosition(myMagicNumber.magicNumber,indic.symbol) == 0)  {
         
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
         
         }
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
