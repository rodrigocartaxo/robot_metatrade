//+------------------------------------------------------------------+
//| MACD EA Multicurrency.mq5                                          |
//| Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader.       |
//| https://youtube.com/@ForexAlgo-Trader?                            |
//+------------------------------------------------------------------+
#property version "2.00"

#include <.\Personal\\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>


// Parâmetros de entrada
input group "==== Configurações MACD ===="
input ENUM_TIMEFRAMES       iTimeFrame         = PERIOD_M5;     // Timeframe
input int                   ifastEmaPeriod     = 12;            // Período EMA Rápida
input int                   iSlowEmaPeriod     = 26;            // Período EMA Lenta
input int                   iSignalPeriod      = 9;             // Período Sinal
input ENUM_APPLIED_PRICE    iAppliedPrice      = PRICE_CLOSE;   // Preço Aplicado


struct SymbolData {
    string symbol;
    int handle;
    double macdMAIN[];
    double macdSIGNAL[];
    int previousBars;
};

// Variáveis globais
SymbolData symbolsData[];
MyPainel painel;
MyMagicNumber myMagicNumber;
TraderInfos tradeInfos;
MyCtrader trade;

//+------------------------------------------------------------------+
//| Inicializa dados para um símbolo                                   |
//+------------------------------------------------------------------+
bool InitSymbolData(SymbolData &data, string symbol) {
    if(symbol == "") return false;
    
    data.symbol = symbol;
    data.handle = iMACD(symbol, iTimeFrame, ifastEmaPeriod, iSlowEmaPeriod, iSignalPeriod, iAppliedPrice);
    
    if(data.handle == INVALID_HANDLE) {
        Print("Erro ao inicializar MACD para ", symbol);
        return false;
    }
    
    ArraySetAsSeries(data.macdMAIN, true);
    ArraySetAsSeries(data.macdSIGNAL, true);
    data.previousBars = 0;
    
    return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
     
    // Preparar array de símbolos
    string symbols[];
    ushort sep_code = StringGetCharacter(sep,0);
    StringSplit(currencies,sep_code,symbols);
    
    // Inicializar array de dados dos símbolos
    for(int i=0; i<ArraySize(symbols); i++) {
        if(symbols[i] != "") {
            ArrayResize(symbolsData, ArraySize(symbolsData) + 1);
            if(!InitSymbolData(symbolsData[ArraySize(symbolsData)-1], symbols[i])) {
                return INIT_FAILED;
            }
        }
    }
    
    if(ArraySize(symbolsData) == 0) {
        Print("Erro: Nenhum símbolo válido configurado");
        return INIT_FAILED;
    }
    
    tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), painel.getShortCurrencies());
    
    if(!painel.OnInit(myMagicNumber.magicNumber)) 
        return INIT_FAILED;
    
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    for(int i=0; i<ArraySize(symbolsData); i++) {
        if(symbolsData[i].handle != INVALID_HANDLE) {
            IndicatorRelease(symbolsData[i].handle);
        }
        ArrayFree(symbolsData[i].macdMAIN);
        ArrayFree(symbolsData[i].macdSIGNAL);
    }
    
    ArrayFree(symbolsData);
    painel.Destroy(reason);
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Verifica sinais de trading para um símbolo                        |
//+------------------------------------------------------------------+
void CheckTradingSignals(SymbolData &data) {
    
    if(!CopyBuffer(data.handle, MAIN_LINE, 0, 3, data.macdMAIN)) {
       Print("Error on Signals ");
       return;
    }
    if(!CopyBuffer(data.handle, SIGNAL_LINE, 0, 3, data.macdSIGNAL)){
       
       Print("Error on Signals ");
       return;
    }
    
    if(ArraySize(data.macdMAIN) < 3 || ArraySize(data.macdSIGNAL) < 3) {
      Print("Error on Signals ");
      return;
    }
    
    
    double price_step = SymbolInfoDouble(data.symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(HasPosition(tradeInfos.iMagicNumber, data.symbol) != 0) return;
    
    // Lógica de compra
    if(data.macdMAIN[0] < 0 && data.macdMAIN[2] > data.macdSIGNAL[2] && 
       data.macdMAIN[1] < data.macdSIGNAL[1]) {
        
        double entry_price = SymbolInfoDouble(data.symbol, SYMBOL_ASK);
        double sl = roundPriceH9K(entry_price - (entry_price * iStopLossPercent / 100), price_step);
        double tp = roundPriceH9K(entry_price + (entry_price * iTakeProfitPercent / 100), price_step);
        
        tradeInfos.symbol = data.symbol;
        tradeInfos.amount = entry_price;
        tradeInfos.order_type = ORDER_TYPE_BUY;
        tradeInfos.order_type_time = ORDER_TIME_GTC;
        tradeInfos.stop_loss = sl;
        tradeInfos.take_profit = tp;
        tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + data.symbol;
        
        trade.sendOrder(tradeInfos);
    }
    
    // Lógica de venda
    else if(data.macdMAIN[0] > 0 && data.macdMAIN[2] < data.macdSIGNAL[2] && 
            data.macdMAIN[1] > data.macdSIGNAL[1]) {
        
        double entry_price = SymbolInfoDouble(data.symbol, SYMBOL_BID);
        double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent / 100), price_step);
        double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent / 100), price_step);
        
        tradeInfos.symbol = data.symbol;
        tradeInfos.amount = entry_price;
        tradeInfos.order_type = ORDER_TYPE_SELL;
        tradeInfos.order_type_time = ORDER_TIME_GTC;
        tradeInfos.stop_loss = sl;
        tradeInfos.take_profit = tp;
        tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + data.symbol;
        
        trade.sendOrder(tradeInfos);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
    painel.OnTick();
    
    for(int i=0; i<ArraySize(symbolsData); i++) {
        int currentBars = iBars(symbolsData[i].symbol, iTimeFrame);
        if(currentBars == symbolsData[i].previousBars) continue;
        symbolsData[i].previousBars = currentBars;
        
        CheckTradingSignals(symbolsData[i]);
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
    painel.PanelChartEvent(id, lparam, dparam, sparam);
}