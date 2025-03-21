//+------------------------------------------------------------------+
//|                 Fibonacci Tracker com Estrutura de Dados         |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>

#property strict
MqlRates rates[];
string iMagicNumber = 556200;
CTrade ctrade;

// Estrutura para armazenar os valores das linhas de Fibonacci
struct FibonacciData
{
   ENUM_TIMEFRAMES perido;
   double level_0;        // Nível 0% (mínimo)
   double level_23_6;     // Nível 23.6%
   double level_38_2;     // Nível 38.2%
   double level_50;       // Nível 50%
   double level_61_8;     // Nível 61.8%
   double level_100;      // Nível 100% (máximo)
   double level_161_8;    // Nível 161.8% (extensão)
};

FibonacciData fibData[];   // Array para armazenar os dados das Fibo
datetime lastTime = 0;          // Para rastrear o tempo do último candle

//+------------------------------------------------------------------+
//| Função para calcular Fibonacci                                   |
//+------------------------------------------------------------------+
FibonacciData CalculateFibonacci(double open, double close, double high, double low)
{
   FibonacciData fib;

   if(close > open) // Candle Positivo
   {
      fib.level_0 = open;
      fib.level_100 = close;
      fib.level_161_8 = close + (close - open) * 0.618;
   }
   else // Candle Negativo
   {
      fib.level_0 = close;
      fib.level_100 = open;
      fib.level_161_8 = close - (open - close) * 0.618;
   }

   // Sempre calcula outros níveis entre o 0% e o 100%
   fib.level_23_6 = fib.level_0 + (fib.level_100 - fib.level_0) * 0.236;
   fib.level_38_2 = fib.level_0 + (fib.level_100 - fib.level_0) * 0.382;
   fib.level_50 = fib.level_0 + (fib.level_100 - fib.level_0) * 0.50;
   fib.level_61_8 = fib.level_0 + (fib.level_100 - fib.level_0) * 0.618;
   fib.perido = _Period;

   return fib;
}


//+------------------------------------------------------------------+
//| Inicialização do EA                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA iniciado. Fibonacci será calculada a cada candle.");
   ArraySetAsSeries(rates, true);
   ctrade.SetExpertMagicNumber(iMagicNumber); 
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função principal                                                 |
//+------------------------------------------------------------------+
void OnTick()
{

   if (!isNewBar()) return;

    int copied  = CopyRates(_Symbol, _Period, 0, 3, rates);
    if(copied <= 0) return; //Caso não consiga pegar as cotações, retorna
     

   // Obtém o tempo do último candle no gráfico
   datetime currentTime = iTime(_Symbol, _Period, 0);

   // Se um novo candle foi formado
   if(currentTime != lastTime)
   {
      lastTime = currentTime; // Atualiza o último tempo

      // Obtém os preços do candle anterior (1)
      double high = iHigh(_Symbol, _Period, 1);
      double low = iLow(_Symbol, _Period, 1);
      
     

      // Calcula a Fibonacci
      FibonacciData fib = CalculateFibonacci( iOpen(_Symbol, _Period, 1),iClose(_Symbol, _Period, 1), high, low);

      // Adiciona os dados ao array
      ArrayResize(fibData, ArraySize(fibData) + 1);
      fibData[ArraySize(fibData) - 1] = fib;

      // Exibe os valores no console
      PrintFormat("Novo Fibonacci: 0%%=%.5f, 23.6%%=%.5f, 38.2%%=%.5f, 50%%=%.5f, 61.8%%=%.5f, 100%%=%.5f, 161.8%%=%.5f" ,"Perido [&d] " , 
                  fib.level_0, fib.level_23_6, fib.level_38_2, fib.level_50, fib.level_61_8, fib.level_100, fib.level_161_8,fib.perido);
   }
}

//+------------------------------------------------------------------+
//| Finalização do EA                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA finalizado. Total de Fibo calculadas: ", ArraySize(fibData));
   for(int i = 0; i < ArraySize(fibData); i++)
   {
      PrintFormat("Fibo %d: 0%%=%.5f, 23.6%%=%.5f, 38.2%%=%.5f, 50%%=%.5f, 61.8%%=%.5f, 100%%=%.5f, 161.8%%=%.5f", 
                  i+1, fibData[i].level_0, fibData[i].level_23_6, fibData[i].level_38_2, 
                  fibData[i].level_50, fibData[i].level_61_8, fibData[i].level_100, fibData[i].level_161_8);
   }
}
