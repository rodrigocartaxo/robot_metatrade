#property copyright "Seu Nome"
#property link      "https://seu-site.com"
#property version   "1.00"
#property strict

// Parâmetros de entrada
input int    RangePeriod = 18;      // Número de candles para calcular o range
input double LotesPadrao = 1.0;     // Número de lotes para operar
input double StopLoss = 50;          // Stop Loss em pontos
input double TakeProfit = 100;       // Take Profit em pontos

// Variáveis globais
double RangeMaximo;
double RangeMinimo;
datetime UltimoCandle;

int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   // Verifica se é um novo candle
   if(UltimoCandle != iTime(_Symbol, _Period, 0))
   {
      UltimoCandle = iTime(_Symbol, _Period, 0);
      
      // Calcula o Range dos primeiros 18 candles
      if(CalcularRange())
      {
         // Lógica de entrada para compra
         if(VerificarCompraBaixaAlta())
         {
            RealizarCompra();
         }
         
         // Lógica de entrada para venda
         if(VerificarVendaAltaBaixa())
         {
            RealizarVenda();
         }
      }
   }
}

bool CalcularRange()
{
   RangeMaximo = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, RangePeriod, 1));
   RangeMinimo = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, RangePeriod, 1));
   
   return true;
}

bool VerificarCompraBaixaAlta()
{
   double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (precoAtual > RangeMaximo);
}

bool VerificarVendaAltaBaixa()
{
   double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (precoAtual < RangeMinimo);
}

void RealizarCompra()
{
   double stop = SymbolInfoDouble(_Symbol, SYMBOL_BID) - StopLoss * _Point;
   double take = SymbolInfoDouble(_Symbol, SYMBOL_BID) + TakeProfit * _Point;
   
   //OrderSend(_Symbol, OP_BUY, LotesPadrao, Ask, 3, stop, take, "Compra Range18", 0, 0, Green);
}

void RealizarVenda()
{
   double stop = SymbolInfoDouble(_Symbol, SYMBOL_BID) + StopLoss * _Point;
   double take = SymbolInfoDouble(_Symbol, SYMBOL_BID) - TakeProfit * _Point;
   
   //OrderSend(_Symbol, OP_SELL, LotesPadrao, Bid, 3, stop, take, "Venda Range18", 0, 0, Red);
}