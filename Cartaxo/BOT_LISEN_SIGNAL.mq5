//+------------------------------------------------------------------+
//|                                           SignalListener.mq5       |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "SignalListener"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>

// Parâmetros de entrada
input string SignalEAName = ""; // Nome do EA que envia sinais
input double LotSize     = 0.1; // Tamanho do Lote
input int    StopLoss    = 100; // Stop Loss em pontos
input int    TakeProfit  = 200; // Take Profit em pontos

CTrade trade;

// Estrutura para armazenar o sinal
struct SignalInfo
{
    int type;      // 1 para compra, -1 para venda, 0 para nenhum sinal
    double price;  // Preço do sinal
    datetime time; // Hora do sinal
};

// Variável global para armazenar o último sinal
SignalInfo lastSignal;

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
    // Inicializa o último sinal
    lastSignal.type = 0;
    lastSignal.price = 0;
    lastSignal.time = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom function to clean global variables                          |
//+------------------------------------------------------------------+
void CleanGlobalVariables(){
    string baseVarName = SignalEAName + "_Signal";
    
    // Remove todas as variáveis globais relacionadas ao sinal
    GlobalVariableDel(baseVarName);
    GlobalVariableDel(SignalEAName + "_Price");
    GlobalVariableDel(SignalEAName + "_Time");
    
    Print("Variáveis globais de sinal limpas");
}

//+------------------------------------------------------------------+
//| Custom function to process signals                                 |
//+------------------------------------------------------------------+
void ProcessSignal(const SignalInfo &signal){
    if(signal.type == 0) return; // Sem sinal
    
    // Verifica se já existe uma posição aberta
    //if(PositionsTotal() > 0) return;
    
    if(signal.type == 1) // Sinal de compra
   {
        double askPrice = signal.price;
        double sl = askPrice - StopLoss * _Point;
        double tp = askPrice + TakeProfit * _Point;
        
        trade.Buy(LotSize, _Symbol, askPrice, sl, tp, "Sinal Recebido - Compra");
    }
    else if(signal.type == -1) // Sinal de venda
    {
        double bidPrice = signal.price; //SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = bidPrice + StopLoss * _Point;
        double tp = bidPrice - TakeProfit * _Point;
        
        trade.Sell(LotSize, _Symbol, bidPrice, sl, tp, "Sinal Recebido - Venda");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Verifica se existe um novo sinal através de variável global
    string globalVarName = SignalEAName + "_Signal";
    
    if(GlobalVariableCheck(globalVarName))
    {
        SignalInfo currentSignal;
        
        // Obtém o sinal da variável global
        currentSignal.type = (int)GlobalVariableGet(globalVarName);
        currentSignal.price = GlobalVariableGet(SignalEAName + "_Price");
        currentSignal.time = (datetime)GlobalVariableGet(SignalEAName + "_Time");
        
        // Verifica se é um novo sinal
        if(currentSignal.time > lastSignal.time)
        {
            Print("Novo sinal recebido: ", currentSignal.type == 1 ? "Compra" : "Venda", 
                  " em ", currentSignal.price, " : ", globalVarName);
                  
            ProcessSignal(currentSignal);
            lastSignal = currentSignal;
            
            // Limpa as variáveis globais após processar o sinal
            CleanGlobalVariables();
        }
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Limpa as variáveis globais quando o EA é removido
    CleanGlobalVariables();
}