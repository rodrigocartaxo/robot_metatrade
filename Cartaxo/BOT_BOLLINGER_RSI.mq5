//+------------------------------------------------------------------+
//|                                            BOT_BOLLINGER_RSI.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>

#include <Indicators\Trend.mqh>
   CiBands     bollinger;
   CiBands     tpBol;
   CiIchimoku  ichimoku;
   CiMA        movAgFast , movAvg200Slow;

#include <Indicators\Oscilators.mqh> 
   CiRSI rsi;

   enum IcTypes {price_above_cloud =  0 ,
                 price_above_ten   =  1 ,
                 price_above_kij   =  2 ,
                 price_above_sena  =  3 ,
                 price_above_senb  =  4 ,
                 ten_above_kij     =  5
                  } ;

input group "==== RSI Filter ====";
input ENUM_TIMEFRAMES       iRSItimeFrame            = PERIOD_M1; //RSI Time frame 
input int                   iRSILevelUpper           = 134; // RSI Level Upper
input int                   iRSILevelLower           = 59; // RSI Level Lower
input int                   iRSIPeiod                = 14; // RSI Peiod 
input ENUM_APPLIED_PRICE    appPriceRSI              = PRICE_CLOSE; // RSI Apllied Price 
input group "==== Bollinger Filter ====";
input ENUM_TIMEFRAMES       iBollingerIimeFrame      = PERIOD_M5; //Bollinger Time frame 
input int                   iBollingerPeriod         = 20; // Bollinger Period 
input int                   iBollingerStdDev         = 2; // Bollinger StdDev
input ENUM_APPLIED_PRICE    appPriceBollinger        = PRICE_CLOSE; // Moving Avg Bollinger Price 

input group "==== Movinng Average Filter ====";
input bool                 ifilterAvgOn            = true; // Enable Avg filter  
input int                  iFastPeriod             = 1376; // Avg Fast Period 
input int                  iSlowPeriod             = 347;  // Avg Slow Period 
input ENUM_TIMEFRAMES      iAvgTimeFrame           = PERIOD_M1;  // Time Frame Avg Period 
input ENUM_APPLIED_PRICE   iappPriceAvg            = PRICE_OPEN; // Moving Avg Apllied Price 
input ENUM_MA_METHOD       iMAMode                 = MODE_SMA; // Moving MODE

input group "==== Ichimoku  Filter ====";
input bool                 iFilteChimokurOn           = true; // Enable Ichimoku filter  
input IcTypes              icTypes                    = 1; // Ichimoku Filter Type
input ENUM_TIMEFRAMES      inputIchimokuTimeFrame     = PERIOD_M20;  // Time Frame Avg Period 
input int                  tenkan                     = 43; 
input int                  kinjun                     = 79;
input int                  senkou                     = 197;



MyPainel painel;
TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;
MyCtrader trade;

string sep = ",";
string V_Currencies[];
int lenghtArray =0;
string BarsTraded [][2];  



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),currencies);
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
      

   ChartSetInteger(0,CHART_SHOW_GRID,false);
    ushort sep_code = StringGetCharacter(sep,0);
    lenghtArray = StringSplit(currencies,sep_code,V_Currencies);
    ArrayResize(BarsTraded,lenghtArray);
    
    for(int i=lenghtArray-1;i>=0;i-- ){
         BarsTraded[i][0] = V_Currencies[i]; 
         BarsTraded[i][1] = IntegerToString(i);
   }
   

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   bollinger.DeleteFromChart(0,0);
   tpBol.DeleteFromChart(0,0);
   ichimoku.DeleteFromChart(0,0);
   movAgFast.DeleteFromChart(0,0); 
   movAvg200Slow.DeleteFromChart(0,0);
   
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
 

/*
void setBarsTraded(string symbol){
   
   for(int i=ArraySize(V_Currencies)-1;i>=0;i-- ){
         string tradesymbol = BarsTraded[i][0];
         int barsnow = iBars(symbol,timeFrame);
         if (tradesymbol==symbol){
            BarsTraded[i][1] = IntegerToString(barsnow);
         } 
   }

}

int getBarsLastTraded(string symbol){
   
   int lastBar =0;
   for(int i=ArraySize(V_Currencies)-1;i>=0;i-- ){
      string tradesymbol = BarsTraded[i][0];
      if (tradesymbol==symbol){
           lastBar = (int)(BarsTraded[i][1]);
         }
   }
   return lastBar;
}
*/
string priceMovAvg(double maFast, double maSlow ){
   
      if(maFast>maSlow)return "above"; 
      if(maFast<maSlow)return "below";
      
      return "error";      
}


string priceIsCloud(string symbol, double senA , double senb, double ten , double kij){
      
      double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
      if (icTypes == 0){
         if (ask>senA && ask > senb )return "above";
          if (ask<senA && ask < senb )return "below";
      }
      if (icTypes == 1){
         if (ask>ten) return "above";
         if (ask<ten) return "below";
      }
      if (icTypes == 2){
         if (ask>kij) return "above";
         if (ask<kij) return "below";
      }
      if (icTypes == 3){
         if (ask>senA) return "above";
         if (ask<senA) return "below";
      } 
      if (icTypes == 4){
         if (ask>senb) return "above";
         if (ask<senb) return "below";
      
      }
      if (icTypes == 5){
         if (ten>kij) return "above";
         if (ten<kij) return "below";
      
      }   
      
return "Incloud" ;
      
   
}
 

void runBySymbol(string symbol){
    
    
     bollinger = new  CiBands;
     bollinger.Create(symbol,iBollingerIimeFrame,iBollingerPeriod,0,iBollingerStdDev,appPriceBollinger);
     
     rsi = new CiRSI;
     rsi.Create(symbol,iRSItimeFrame,iRSIPeiod,appPriceRSI); 
     
     rsi.Refresh(-1); 
     bollinger.Refresh(-1);
     
     double fastMA = 0 , slowMA = 0;
     double senA = 0 , senB = 0, ten = 0 , kij = 0;
     
     if (ifilterAvgOn){
         movAgFast = new CiAMA;   
         movAgFast.Create(symbol,iAvgTimeFrame,iFastPeriod,0,iMAMode,iappPriceAvg);
         movAgFast.Refresh(-1);
         
         movAvg200Slow = new CiAMA;   
         movAvg200Slow.Create(symbol,iAvgTimeFrame,iSlowPeriod,0,iMAMode,iappPriceAvg);
         movAvg200Slow.Refresh(-1);
         
         fastMA   = movAgFast.Main(1);
         slowMA = movAvg200Slow.Main(1);
         
     }
     
     if (iFilteChimokurOn){
         ichimoku = new CiIchimoku;
         ichimoku.Create(symbol,inputIchimokuTimeFrame,tenkan,kinjun,senkou);
         ichimoku.Refresh(-1);
         
         senA = ichimoku.SenkouSpanA(1);
         senB = ichimoku.SenkouSpanB(1);
         ten  = ichimoku.TenkanSen(1);
         kij  = ichimoku.KijunSen(1);
         
     }
     
     
     double ask   = SymbolInfoDouble(symbol,SYMBOL_ASK);
     double bid   = SymbolInfoDouble(symbol,SYMBOL_BID);
     
     double close = iClose(symbol,iTradeTimeFrame,1);
     
     //double barLastTraded = getBarsLastTraded(symbol);
     
     /*int barNow = iBars(symbol,timeFrame);
     double var_bar_now  = barLastTraded + BarsSince; */
     
     double lots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;
     double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick
     
     if (close < bollinger.Lower(1) //&& barNow > var_bar_now 
         && rsi.Main(0)> iRSILevelLower){
         if(ifilterAvgOn && priceMovAvg(fastMA,slowMA)!="above") return; 
         if(iFilteChimokurOn && priceIsCloud(symbol,senA,senB,ten,kij)!="above") return; 
         
         double tp = bollinger.Upper(0);
         //comprar 
         double sl           = roundPriceH9K(ask - (ask *iStopLossPercent /100),price_step);
         
         tradeInfos.lot_size = lots;
         tradeInfos.amount   = ask;
         tradeInfos.order_type = ORDER_TYPE_BUY;
         tradeInfos.stop_loss =sl; 
         tradeInfos.take_profit =tp; 
         tradeInfos.message = "BOT BOLLINGER  RSI:"+ symbol;
         trade.sendOrder(tradeInfos); 
         
         
        //setBarsTraded(symbol);
         
     }
     if (close > bollinger.Upper(1) //&& barNow > var_bar_now 
         && rsi.Main(0)> iRSILevelUpper){
         if(ifilterAvgOn && priceMovAvg(fastMA,slowMA)!="below") return; 
         if(iFilteChimokurOn && priceIsCloud(symbol,senA,senB,ten,kij)!="below") return; 
         
         double tp = bollinger.Lower(0);
         double sl           = roundPriceH9K(bid + (bid *iStopLossPercent /100),price_step);
         
         tradeInfos.lot_size = lots;
         tradeInfos.amount   = ask;
         tradeInfos.order_type = ORDER_TYPE_SELL;
         tradeInfos.stop_loss =sl; 
         tradeInfos.take_profit =tp; 
         tradeInfos.message = "BOT BOLLINGER  RSI:"+ symbol;
         trade.sendOrder(tradeInfos); 
         
         //vander 
        //setBarsTraded(symbol);
         
     } 
}
