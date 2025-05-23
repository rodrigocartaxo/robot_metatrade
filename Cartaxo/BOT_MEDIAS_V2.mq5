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
#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>

#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>




//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input group "==== Params ====";
input   int inputFastPeriodo            = 5;
input   int inputSlowPeriodo            = 10;
input   ENUM_TIMEFRAMES inputTimeFrame  = PERIOD_M5;  


//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
MyPainel painel;
TraderInfos tradeInfos;

double fastBuffer[];
double slowBuffer[];
MyCtrader trade;

MyMagicNumber myMagicNumber;

string _sep = ",";
string _V_Currencies[];
int _lenghtArray =0; 

struct SIndicators {
   int emaSlow;
   int emaFast;
   string symbol;
   ulong magicNumber; 
   
   // Construtor para inicialização segura
   SIndicators() {
      emaSlow = INVALID_HANDLE;
      emaFast = INVALID_HANDLE;
      symbol = "";
      magicNumber = 0;
   }
   
   // Método para verificar se os handles são válidos
   bool isValid() const {
      return (emaSlow != INVALID_HANDLE && emaFast != INVALID_HANDLE);
   }
   
   // Método para liberar handles
   void releaseHandles() {
      if(emaFast != INVALID_HANDLE) {
         IndicatorRelease(emaFast);
         emaFast = INVALID_HANDLE;
      }
      if(emaSlow != INVALID_HANDLE) {
         IndicatorRelease(emaSlow);
         emaSlow = INVALID_HANDLE;
      }
   }
};


SIndicators vSIndicators[];
string shortCurrencies[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   
   //tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),painel.getShortCurrencies());
   
   painel.getShortCurrencies(shortCurrencies);
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   

   ushort sep_code = StringGetCharacter(_sep,0);
   _lenghtArray = StringSplit(currencies,sep_code,_V_Currencies);
   ArrayResize(vSIndicators,_lenghtArray);
   
   for(int i=_lenghtArray-1;i>=0;i-- ){
       vSIndicators[i]=  initIndicators(_V_Currencies[i]);
       vSIndicators[i].magicNumber =  myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),shortCurrencies[i]);  
   }

   
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true); 
   EventSetTimer(1);    

   return(INIT_SUCCEEDED);
}
  
SIndicators initIndicators(string symbol){
   SIndicators s;
   s.symbol = symbol;
   
   // Criar handle para EMA rápida
   Print("Init iMAFast ", symbol);
   s.emaFast = iMA(symbol, inputTimeFrame, inputFastPeriodo, 0, MODE_SMA, PRICE_CLOSE);
   if(s.emaFast == INVALID_HANDLE) {
      Print("Erro crítico: Falha ao criar handle EMA rápida para ", symbol);
      return s;  // Retorna struct com handles inválidos
   }
   
   // Criar handle para EMA lenta
   Print("Init iMASlow ", symbol);
   s.emaSlow = iMA(symbol, inputTimeFrame, inputSlowPeriodo, 0, MODE_SMA, PRICE_CLOSE);
   if(s.emaSlow == INVALID_HANDLE) {
      // Se falhar, libera o handle já criado
      IndicatorRelease(s.emaFast);
      s.emaFast = INVALID_HANDLE;
      Print("Erro crítico: Falha ao criar handle EMA lenta para ", symbol);
      return s;  // Retorna struct com handles inválidos
   }
   
   
   
   
  return s;


}  
  
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
      
      EventKillTimer();
     
      for(int i = 0; i < _lenghtArray; i++) {
      if(vSIndicators[i].emaFast != INVALID_HANDLE) {
         IndicatorRelease(vSIndicators[i].emaFast);
         vSIndicators[i].emaFast = INVALID_HANDLE;
      }
      if(vSIndicators[i].emaSlow != INVALID_HANDLE) {
         IndicatorRelease(vSIndicators[i].emaSlow);
         vSIndicators[i].emaSlow = INVALID_HANDLE;
      }
   }
      
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
      for(int i=_lenghtArray-1;i>=0;i-- ){
      SIndicators indic =   vSIndicators[i]; 
     
         if(!indic.isValid()) {
            Print("Handles inválidos para ", indic.symbol, ". Tentando reinicializar...");
            indic.releaseHandles();  // Libera handles antigos se existirem
            indic = initIndicators(indic.symbol);  // Tenta reinicializar
            if(!indic.isValid()) {
               Print("Falha na reinicialização dos handles para ", indic.symbol);
               continue;  // Pula para o próximo símbolo
            }
         }
         
         // Copia dados do buffer rápido
         int values = CopyBuffer(indic.emaFast, 0, 0, 2, fastBuffer);
         if(values != 2) {
            Print("Falha ao ler buffer EMA rápida para ", indic.symbol);
            continue;
         }
         
         // Copia dados do buffer lento
         values = CopyBuffer(indic.emaSlow, 0, 0, 2, slowBuffer);
         if(values != 2) {
            Print("Falha ao ler buffer EMA lenta para ", indic.symbol);
            continue;
         }
        

         tradeInfos.symbol = indic.symbol;
         tradeInfos.iMagicNumber = indic.magicNumber; 
         
         double price_step = SymbolInfoDouble( indic.symbol, SYMBOL_TRADE_TICK_SIZE );
    
        if(fastBuffer[1]<= slowBuffer[1] && fastBuffer[0]>slowBuffer[0] && ( HasPosition(myMagicNumber.magicNumber,tradeInfos.symbol ) == 0) ){
        
            double entry_price  = SymbolInfoDouble(indic.symbol, SYMBOL_ASK);
            double sl           = roundPriceH9K(entry_price - (entry_price *iStopLossPercent /100),price_step);
            double tp           = roundPriceH9K(entry_price + (entry_price *iTakeProfitPercent /100) ,price_step);
            
            tradeInfos.amount   = entry_price;
            tradeInfos.order_type = ORDER_TYPE_BUY;
            tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
            tradeInfos.stop_loss =sl; 
            tradeInfos.take_profit =tp; 
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ " "  +  indic.symbol;
            trade.sendOrder(tradeInfos); 
             
        }else if(fastBuffer[1]>= slowBuffer[1] && fastBuffer[0]<slowBuffer[0] && ( HasPosition(myMagicNumber.magicNumber,tradeInfos.symbol) == 0) ){
            
            double entry_price  = SymbolInfoDouble(indic.symbol, SYMBOL_BID);
            double sl           = roundPriceH9K(entry_price + (entry_price *iStopLossPercent /100),price_step);
            double tp           = roundPriceH9K(entry_price - (entry_price *iTakeProfitPercent /100) ,price_step);
            
            //tradeInfos.lot_size        = lots;
            tradeInfos.amount          = entry_price;
            tradeInfos.order_type      = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
            tradeInfos.stop_loss       = sl; 
            tradeInfos.take_profit     = tp;
            tradeInfos.message         = MQLInfoString(MQL_PROGRAM_NAME)+ " "  + indic.symbol;
            trade.sendOrder(tradeInfos);
        } 
         
      }     
     
     
  }
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );

}


