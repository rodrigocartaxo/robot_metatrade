//+------------------------------------------------------------------+
//|                                    MovingAverageAntecipation.mq5 |
//|                                Copyright 2025, MetaQuotes Ltd.   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>

#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
TraderInfos tradeInfos;
MyCtrader trade;
MyMagicNumber myMagicNumber;


// Parâmetros de entrada
input int FastWindow = 7;        // Período da média móvel rápida
input int SlowWindow = 40;       // Período da média móvel lenta
input double VolatilityFactor = 1.0; // Fator de volatilidade
input bool Verbose = true;       // Exibir logs detalhados

//+------------------------------------------------------------------+
//| Função para determinar sinal de negociação                       |
//+------------------------------------------------------------------+
int GetMovingAverageAntecipationTradeSignal(
    double &close_price[],        // Array de preços de fechamento
    int bars_count,               // Número de barras disponíveis
    double volatility_factor,     // Fator de volatilidade para antecipação
    int fast_window,              // Janela da média rápida
    int slow_window,              // Janela da média lenta
    bool verbose                  // Exibir logs detalhados
)
{
    // Verifica se há dados suficientes
    if(bars_count < slow_window) {
        if(verbose) Print("❌ Dados insuficientes para calcular médias móveis. Pulando...");
        return 0; // 0 = sem sinal
    }
    
    // Aloca arrays para médias móveis e volatilidade
    double ma_fast[];
    double ma_slow[];
    double volatility[];
    
    ArrayResize(ma_fast, bars_count);
    ArrayResize(ma_slow, bars_count);
    ArrayResize(volatility, bars_count);
    
    // Calcula as médias móveis
    for(int i = 0; i < bars_count; i++) {
        // Média rápida
        if(i >= fast_window - 1) {
            double sum = 0;
            for(int j = 0; j < fast_window; j++) {
                sum += close_price[i - j];
            }
            ma_fast[i] = sum / fast_window;
        } else {
            ma_fast[i] = 0; // Valor inválido
        }
        
        // Média lenta
        if(i >= slow_window - 1) {
            double sum = 0;
            for(int j = 0; j < slow_window; j++) {
                sum += close_price[i - j];
            }
            ma_slow[i] = sum / slow_window;
        } else {
            ma_slow[i] = 0; // Valor inválido
        }
        
        // Calcula a volatilidade (desvio padrão)
        if(i >= slow_window - 1) {
            double sum = 0;
            double sum_squares = 0;
            
            for(int j = 0; j < slow_window; j++) {
                sum += close_price[i - j];
                sum_squares += MathPow(close_price[i - j], 2);
            }
            
            double mean = sum / slow_window;
            double variance = (sum_squares / slow_window) - MathPow(mean, 2);
            volatility[i] = MathSqrt(variance);
        } else {
            volatility[i] = 0; // Valor inválido
        }
    }
    
    // Verifica se há dados válidos suficientes após os cálculos
    if(ma_fast[bars_count - 1] == 0 || ma_slow[bars_count - 1] == 0) {
        if(verbose) Print("⚠️ Ainda há poucos dados após calcular médias. Pulando...");
        return 0;
    }
    
    // Obtém os valores mais recentes
    double last_ma_fast = ma_fast[bars_count - 1];
    double prev_ma_fast = ma_fast[bars_count - 3]; // 3 barras atrás como no código original
    double last_ma_slow = ma_slow[bars_count - 1];
    double prev_ma_slow = ma_slow[bars_count - 3];
    
    // Verifica a volatilidade
    double last_volatility = volatility[bars_count - 2]; // Penúltima como no código original
    if(last_volatility == 0) return 0;
    
    // Calcula o gradiente (mudança) das médias móveis
    double fast_gradient = last_ma_fast - prev_ma_fast;
    double slow_gradient = last_ma_slow - prev_ma_slow;
    
    // Calcula a diferença atual entre as médias
    double current_difference = MathAbs(last_ma_fast - last_ma_slow);
    
    // Inicializa a decisão (1=Comprar, -1=Vender, 0=Nenhuma ação)
    int ma_trade_decision = 0;
    
    // Toma a decisão com base em volatilidade + gradiente
    if(current_difference < last_volatility * volatility_factor) {
        if(fast_gradient > 0 && fast_gradient > slow_gradient) {
            ma_trade_decision = 1;  // Comprar
        } else if(fast_gradient < 0 && fast_gradient < slow_gradient) {
            ma_trade_decision = -1;  // Vender
        }
    }
    
    // Log da estratégia e decisão
    if(verbose) {
        /*Print("-------");
        Print("📊 Estratégia: Moving Average Antecipation");
        Print(" | Última Média Rápida: ", DoubleToString(last_ma_fast, 3));
        Print(" | Última Média Lenta: ", DoubleToString(last_ma_slow, 3));
        Print(" | Última Volatilidade: ", DoubleToString(last_volatility, 3));
        Print(" | Diferença Atual: ", DoubleToString(current_difference, 3));
        Print(" | Diferença para antecipação: ", DoubleToString(volatility_factor * last_volatility, 3));
        Print(" | Gradiente Rápido: ", DoubleToString(fast_gradient, 3), " (", (fast_gradient > 0 ? "Subindo" : "Descendo"), ")");
        Print(" | Gradiente Lento: ", DoubleToString(slow_gradient, 3), " (", (slow_gradient > 0 ? "Subindo" : "Descendo"), ")");
        Print(" | Decisão: ", (ma_trade_decision == 1 ? "Comprar" : (ma_trade_decision == -1 ? "Vender" : "Nenhuma")));
        Print("-------");*/
    }
    
    return ma_trade_decision;
}

//+------------------------------------------------------------------+
//| Função Expert initialization                                     |
//+------------------------------------------------------------------+
int OnInit(){
   
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), currencies);
   tradeInfos.symbol = currencies;
      
 
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função Expert deinitialization                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Limpeza, se necessário
}

//+------------------------------------------------------------------+
//| Função Expert tick                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Obtém dados históricos
    int bars_to_load = SlowWindow * 2; // Carrega pelo menos 2x a janela lenta para ter dados suficientes
    double close_prices[];
    ArraySetAsSeries(close_prices, true); // Configura o array para ordem cronológica inversa (mais recente primeiro)
    int copied = CopyClose(Symbol(), PERIOD_CURRENT, 0, bars_to_load, close_prices);
    
    if(copied < bars_to_load) {
        Print("Não foi possível copiar dados suficientes. Tentando novamente...");
        return;
    }
    
    // Inverte a ordem para compatibilidade com a função de estratégia (mais antigo primeiro)
    double ordered_prices[];
    ArrayResize(ordered_prices, copied);
    for(int i = 0; i < copied; i++) {
        ordered_prices[i] = close_prices[copied - i - 1];
    }
    
    // Obtém o sinal de negociação
    int signal = GetMovingAverageAntecipationTradeSignal(
        ordered_prices, 
        copied, 
        VolatilityFactor, 
        FastWindow, 
        SlowWindow, 
        Verbose
    );
     double price_step = SymbolInfoDouble( currencies, SYMBOL_TRADE_TICK_SIZE );
    // Implementar lógica de negociação baseada no sinal
    if(signal == 1 && HasPosition( tradeInfos.iMagicNumber,_Symbol) ==0 ) {
        // Lógica para abrir posição de compra
        Comment("Sinal: COMPRAR");
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
        
        // Aqui você pode adicionar código para executar ordens de compra
    }
    else if(signal == -1 && HasPosition(tradeInfos.iMagicNumber,_Symbol)==0) {
        // Lógica para abrir posição de venda
        Comment("Sinal: VENDER");
         double entry_price = SymbolInfoDouble(currencies, SYMBOL_BID);
        double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent/100), price_step);
        double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent/100), price_step);
       
       tradeInfos.amount = entry_price;
       tradeInfos.order_type = ORDER_TYPE_SELL;
       tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
       tradeInfos.stop_loss = sl;
       tradeInfos.take_profit = tp;
       tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + currencies;
       trade.sendOrder(tradeInfos);
        // Aqui você pode adicionar código para executar ordens de venda
    }
    else {
        Comment("Sem sinal de negociação");
    }
}
//+------------------------------------------------------------------+