//+------------------------------------------------------------------+
//|                         H9k_YT_TrailingStop_Regressao_Linear.mq5 
//|                                  Copyright (C) 2025 - H9k Trades  
//|                                   https://youtube.com/@h9ktrades
//+------------------------------------------------------------------+

/* Copyright (C) 2025 - H9k Trades 
 * Este programa é software livre; você pode redistribuí-lo e/ou 
 * modificá-lo sob os termos da Licença Pública Geral Menor GNU 
 * conforme publicada pela Free Software Foundation; 
 */

#property copyright "H9k Trades"
#property link      "https://youtube.com/@h9ktrades"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\MyCtrader\TraderInfos.mqh>
#include <.\MyCtrader\MyCtrader.mqh>
#include <.\MyMagicNumber.mqh>
#include <.\MyPainel.mqh>




input group "::::: Regressão Linear"
input int iRLPeriod = 20;                       // Barras para cálculo
input ENUM_TIMEFRAMES iRLTimeFrame = PERIOD_M5; // Timeframe

// Estrutura para armazenar informações de cada par
struct CurrencyPairInfo {
    string symbol;
    int handle_rl;
    double rl_high[];
    double rl_low[];
    double rl_mid[];
    bool initialized;
};

// Arrays e variáveis globais
CurrencyPairInfo pairs[];
MyMagicNumber myMagicNumber;
TraderInfos tradeInfos;
MyCtrader trade;
MyPainel painel;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    // Inicializa o array de pares
    string pair_list[];
    StringSplit(currencies, ',', pair_list);
    ArrayResize(pairs, ArraySize(pair_list));
    
    // Inicializa cada par
    for(int i = 0; i < ArraySize(pair_list); i++) {
        pairs[i].symbol = pair_list[i];
        pairs[i].handle_rl = iCustom(pairs[i].symbol, iRLTimeFrame, "H9k\\H9k_Linear_Regression", iRLPeriod);
        
        if(pairs[i].handle_rl < 0) {
            Print("Erro ao inicializar indicador para ", pairs[i].symbol);
            return INIT_FAILED;
        }
        
        ArraySetAsSeries(pairs[i].rl_high, true);
        ArraySetAsSeries(pairs[i].rl_low, true);
        ArraySetAsSeries(pairs[i].rl_mid, true);
        pairs[i].initialized = true;
    }
    
    // Inicializa o magic number
    tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), currencies);

    if(!painel.OnInit(myMagicNumber.magicNumber)) 
        return INIT_FAILED;
   
    EventSetTimer(1);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Libera os handles dos indicadores
    for(int i = 0; i < ArraySize(pairs); i++) {
        if(pairs[i].handle_rl != INVALID_HANDLE)
            IndicatorRelease(pairs[i].handle_rl);
    }
    painel.Destroy(reason);
    
    EventKillTimer();
    
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
   
   painel.OnTick();

    // Processa cada par de moedas
    for(int i = 0; i < ArraySize(pairs); i++) {
        if(!pairs[i].initialized) continue;
         static bool isNewBar = false;
         int currBars = iBars(pairs[i].symbol, _Period);
         static int prevBars = currBars;
         if (prevBars == currBars) {
             isNewBar = false;
         } else if (prevBars != currBars) {
             isNewBar = true;
            prevBars = currBars;
        } 
        
        if (isNewBar){
         ProcessCurrencyPair(pairs[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Processa um par de moedas específico                              |
//+------------------------------------------------------------------+
void ProcessCurrencyPair(CurrencyPairInfo &pair) {
    // Obtém preços atuais
    double _bid = NormalizeDouble(SymbolInfoDouble(pair.symbol, SYMBOL_BID), _Digits);
    double _ask = NormalizeDouble(SymbolInfoDouble(pair.symbol, SYMBOL_ASK), _Digits);
    
    
    // Atualiza valores da regressão
    if(CopyBuffer(pair.handle_rl, 0, 0, 3, pair.rl_high) <= 0) return;
    if(CopyBuffer(pair.handle_rl, 2, 0, 3, pair.rl_low) <= 0) return;
    if(CopyBuffer(pair.handle_rl, 1, 0, 3, pair.rl_mid) <= 0) return;
    
    tradeInfos.symbol = pair.symbol;
    
    
    // Verifica posições existentes
    int positions_total = HasPosition(myMagicNumber.magicNumber, pair.symbol);
    
    // Lógica de entrada para compra
    if(positions_total == 0 && _ask <= pair.rl_low[0]) {
        OpenBuyPosition(_ask, pair.symbol);
    }
    
    // Lógica de entrada para venda
    if(positions_total == 0 && _bid >= pair.rl_high[0]) {
        OpenSellPosition(_bid, pair.symbol);
    }
}

//+------------------------------------------------------------------+
//| Abre posição de compra                                            |
//+------------------------------------------------------------------+
void OpenBuyPosition(double entry_price, string symbol ) {
    double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double sl = roundPriceH9K(entry_price - (entry_price * iStopLossPercent/100), price_step);
    double tp = roundPriceH9K(entry_price + (entry_price * iTakeProfitPercent/100), price_step);
    
    tradeInfos.amount = entry_price;
    tradeInfos.order_type = ORDER_TYPE_BUY;
    tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
    tradeInfos.stop_loss = sl;
    tradeInfos.take_profit = tp;
    
    tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + symbol;
    
    trade.sendOrder(tradeInfos);
}

//+------------------------------------------------------------------+
//| Abre posição de venda                                             |
//+------------------------------------------------------------------+
void OpenSellPosition(double entry_price, string symbol) {
    double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent/100), price_step);
    double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent/100), price_step);
    
    tradeInfos.amount = entry_price;
    tradeInfos.order_type = ORDER_TYPE_SELL;
    tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
    tradeInfos.stop_loss = sl;
    tradeInfos.take_profit = tp;
    tradeInfos.symbol = symbol;
    tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + symbol;
    
    trade.sendOrder(tradeInfos);
}

//+------------------------------------------------------------------+
//| Função auxiliar para dividir string                               |
//+------------------------------------------------------------------+
void StringSplit(string str, string separator, string &arr[]) {
    int pos = StringFind(str, separator);
    int count = 0;
    
    while(pos != -1) {
        ArrayResize(arr, count + 1);
        arr[count] = StringSubstr(str, 0, pos);
        str = StringSubstr(str, pos + 1);
        pos = StringFind(str, separator);
        count++;
    }
    
    if(StringLen(str) > 0) {
        ArrayResize(arr, count + 1);
        arr[count] = str;
    }
}