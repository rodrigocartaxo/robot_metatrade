//+------------------------------------------------------------------+
//|                                                  BOT_RSI_DIV.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>

#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
TraderInfos tradeInfos;
MyCtrader trade;
MyMagicNumber myMagicNumber;




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int handle = INVALID_HANDLE;
double signal[]; 


int OnInit(){
      
      // Inicialização
      tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), currencies);
      
      Print("EA " + MQLInfoString(MQL_PROGRAM_NAME)+ " inicializado com sucesso : "+ (string)tradeInfos.iMagicNumber);
      
      handle = iCustom(_Symbol,_Period,"Market//RSI Divergence Indicator MT5");
      
      
      if (handle == INVALID_HANDLE){
         Print(" UNABLE TO INITILAZE  ");
         return(INIT_FAILED);
      }
      
      ArraySetAsSeries(signal,true);
   

      return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   
    ArrayFree(signal);
    
     if(handle!= INVALID_HANDLE  ){
      IndicatorRelease(handle);
     }  
    Print("Serviço finalizado");
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
      
      if (CopyBuffer(handle,1,0,1,signal)<1){
            Print(" UNABLE TO INITILAZE ERROR ON COPY BUFFER  ");
           return;
      }

      
      double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE );
      
      
      
      int currBars = iBars(_Symbol,_Period);
      static int prevBars = currBars;
      if (prevBars ==currBars)return;
      prevBars=currBars;
      
      tradeInfos.symbol = _Symbol; 
      
      
      if (signal[0]==1 )  {
      
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = roundPriceH9K(entry_price - (entry_price * iStopLossPercent/100), price_step);
      double tp = roundPriceH9K(entry_price + (entry_price * iTakeProfitPercent/100), price_step);      
       
       tradeInfos.amount = entry_price;
       tradeInfos.order_type = ORDER_TYPE_BUY;
       tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
       tradeInfos.stop_loss = sl;
       tradeInfos.take_profit = tp;
       tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + _Symbol;
       trade.sendOrder(tradeInfos);
   
      } 
      else if (signal[0]==-1)  {
        double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent/100), price_step);
        double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent/100), price_step);
       
       tradeInfos.amount = entry_price;
       tradeInfos.order_type = ORDER_TYPE_SELL;
       tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
       tradeInfos.stop_loss = sl;
       tradeInfos.take_profit = tp;
       tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + _Symbol;
       trade.sendOrder(tradeInfos);
       
      
      }
   
  }
//+------------------------------------------------------------------+
