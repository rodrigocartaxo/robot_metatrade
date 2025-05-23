//+------------------------------------------------------------------+
//|                                                   BOT_MEDIAS.mq5    |
//|                                  Copyright 2024, Rodrigo Cartaxo.   |
//|                                             https://www.mql5.com    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rodrigo Cartaxo."
#property version   "1.00"
#property strict

// Input parameters
input group "==== Params ====";
input string   SYMBOL_LIST      = "WING25,WDOG25";  // Lista de símbolos (separados por vírgula)
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M15;       // Timeframe
input double   THRESHOLD        = 0.2;              // Variation threshold (%)


// Include files
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>

// Global variables
MyPainel painel;
TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;
MyCtrader trade;
datetime lastBarTime = 0;
string symbols[];        // Array para armazenar os símbolos
int symbolCount = 0;     // Quantidade de símbolos

//+------------------------------------------------------------------+
//| Parse symbols string into array                                    |
//+------------------------------------------------------------------+
bool parseSymbols() {
   string tempStr = SYMBOL_LIST;
   symbolCount = StringSplit(tempStr, ',', symbols);
   
   if(symbolCount < 2) {
      Print("Erro: É necessário informar pelo menos 2 símbolos!");
      return false;
   }
   
   // Limpa espaços em branco e valida cada símbolo
   for(int i = 0; i < symbolCount; i++) {
      if(!SymbolSelect(symbols[i], true)) {
         Print("Erro: Símbolo inválido - ", symbols[i]);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for new bar                                                  |
//+------------------------------------------------------------------+
bool isNewBarOveried() {
   datetime currentBarTime = iTime(symbols[0], TIMEFRAME, 0);
   if (currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate price variation                                          |
//+------------------------------------------------------------------+
double calculateVariation(string symbol) {
   double price_current = iClose(symbol, TIMEFRAME, 0);
   double price_previous = iClose(symbol, TIMEFRAME, 1);
   
   if (price_previous == 0) return 0;
   return ((price_current/price_previous) - 1) * 100;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
   // Parse e valida os símbolos
   if(!parseSymbols()) {
      return INIT_FAILED;
   }
   
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), 
                                                    painel.getShortCurrencies());
   
   if (!painel.OnInit(myMagicNumber.magicNumber))
      return INIT_FAILED;
   
   EventSetTimer(1);
   Print("EA iniciado com ", symbolCount, " símbolos: ", SYMBOL_LIST);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   painel.Destroy(reason);
   delete &tradeInfos;
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Chart event handler                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, 
                  const double &dparam, const string &sparam) {
   painel.PanelChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Timer event handler                                                |
//+------------------------------------------------------------------+
void OnTimer() {
   painel.OnTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
   if (!isNewBarOveried()) return;
   
   painel.OnTick();
   
   // Array para armazenar as variações
   double variations[];
   ArrayResize(variations, symbolCount);
   
   // Calcula variações para todos os símbolos
   for(int i = 0; i < symbolCount; i++) {
      variations[i] = calculateVariation(symbols[i]);
   }
   
   // Verifica condições de trading para cada par de símbolos
   for(int i = 0; i < symbolCount-1; i++) {
      for(int j = i+1; j < symbolCount; j++) {
         // Verifica divergência entre os pares
         if (variations[i] > THRESHOLD && variations[j] < -THRESHOLD) {
            Print("Signal: Buy ", symbols[i], " (var: ", DoubleToString(variations[i], 2), "%)");
            Print("Signal: Sell ", symbols[j], " (var: ", DoubleToString(variations[j], 2), "%)");
            // Adicione sua lógica de execução de trades aqui
            openPosition(symbols[i],ORDER_TYPE_BUY);
            openPosition(symbols[j],ORDER_TYPE_SELL);
            
         }
         else if (variations[i] < -THRESHOLD && variations[j] > THRESHOLD) {
            Print("Signal: Sell ", symbols[i], " (var: ", DoubleToString(variations[i], 2), "%)");
            Print("Signal: Buy ", symbols[j], " (var: ", DoubleToString(variations[j], 2), "%)");
            openPosition(symbols[i],ORDER_TYPE_SELL);
            openPosition(symbols[j],ORDER_TYPE_BUY);
         }
      }
   }  
}

void openPosition( string symbol,ENUM_ORDER_TYPE order_type){
            
            double entry_price  = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double price_step   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE );
               
            if (order_type == ORDER_TYPE_BUY){
            
               double sl           = roundPriceH9K(entry_price - (entry_price *iStopLossPercent /100),price_step);
               double tp           = roundPriceH9K(entry_price + (entry_price *iTakeProfitPercent /100) ,price_step);
   
               //tradeInfos.lot_size = lots;
               tradeInfos.amount   = entry_price;
               tradeInfos.order_type = ORDER_TYPE_BUY;
               tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
               tradeInfos.stop_loss =sl; 
               tradeInfos.take_profit =tp; 
               tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ symbol;
               trade.sendOrder(tradeInfos); 
            }else {
               
               double sl           = roundPriceH9K(entry_price + (entry_price *iStopLossPercent /100),price_step);
               double tp           = roundPriceH9K(entry_price - (entry_price *iTakeProfitPercent /100) ,price_step);
            
               //tradeInfos.lot_size = lots;
               tradeInfos.amount   = entry_price;
               tradeInfos.order_type = ORDER_TYPE_SELL;
               tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
               tradeInfos.stop_loss =sl; 
               tradeInfos.take_profit =tp; 
               tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ symbol;
               trade.sendOrder(tradeInfos); 
            }

}
