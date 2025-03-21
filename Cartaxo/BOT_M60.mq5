//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\H9k_Includes\H9k_Panels.mqh>

input int ConsolidationPeriod = 5;  // Período para identificar consolidação
input double RiskRewardRatio    = 2; // Relação risco/recompensa
input double iAmmout            = 1; // Tamanho do lote
input int Slippage              = 3;  // Slippage permitido
input long   iMagicNumber       = 562251;
input string iHoraIni = "09:05:00"; //Hora inicio
input string iHoraFim = "17:30:00"; //Hora fim

double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick
CTrade ctrade;
 MqlRates rates[];
      

int OnInit(){

    ctrade.SetExpertMagicNumber(iMagicNumber);  

    PrintFormat("[%d] Ligando....", iMagicNumber);
    ArraySetAsSeries(rates, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   
   if (!allowed_by_hour(iHoraIni, iHoraFim)) {
        closeAllPositions(ctrade, iMagicNumber);
        closeAllOpenOrders(ctrade, iMagicNumber); 
        return;       
    }

   if (!isNewBar()) return;

   // 1. Identificar Consolidação
   double high = iHigh(NULL, PERIOD_M5, ConsolidationPeriod);
   double low = iLow(NULL, PERIOD_M5, ConsolidationPeriod);
   double range = high - low;
   //Print("range "+range);
   //Print("_Point "+_Point);
  
   // Garantir que a consolidação seja "estreita"
   if(range < 300 * _Point) // Apenas consolidar intervalos pequenos
   {
      // Obter preços atuais
      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       //Print("current_bid "+ current_bid);
       //Print("current_ask "+ current_ask);

      // Obter volumes com CopyRates
     
      if(CopyRates(_Symbol, PERIOD_M5, 0, ConsolidationPeriod, rates) < ConsolidationPeriod)
        {
         Print("Erro ao copiar os dados históricos: ", GetLastError());
         return;
        }

      // Calcular média de volumes
      double avg_volume = CalculateAverageVolume(ConsolidationPeriod);
      double current_volume = roundPriceH9K(rates[0].tick_volume,price_step);
      
           // 2. Verificar rompimento
      // Compra no rompimento da máxima
      if (has_open_order(iMagicNumber)){
            PrintFormat("Existem ordens abertas [%d]", iMagicNumber);
            return;
      }
       /*Print("current_ask "+ current_ask);
       Print("high "+ high);
       Print("low "+ low);
       Print("current_volume "+ current_volume);
       Print("avg_volume "+ avg_volume);*/
        
                   
      if(current_ask > high && current_volume > avg_volume)
        {
         OpenBuy(rates[0].open, range);
        }

      // Venda no rompimento da mínima
      else if(current_bid < low && current_volume > avg_volume)
        {
         OpenSell(rates[0].close, range);
        }
     }
  }

//+------------------------------------------------------------------+
//| Abrir posição de compra                                          |
//+------------------------------------------------------------------+
void OpenBuy(double entry_price, double range){
   double stop_loss = entry_price - range;
   double take_profit = entry_price + range * RiskRewardRatio;

  int ticket = ctrade.BuyLimit(iAmmout, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_DAY, 0);
  
  if(ticket < 0) Print("Erro ao abrir ordem de compra: ", GetLastError());
 
 }

//+------------------------------------------------------------------+
//| Abrir posição de venda                                           |
//+------------------------------------------------------------------+
void OpenSell(double entry_price, double range){
   double stop_loss = entry_price + range;
   double take_profit = entry_price - range * RiskRewardRatio;
   
   int ticket = ctrade.SellLimit(iAmmout, entry_price, _Symbol, stop_loss, take_profit, ORDER_TIME_DAY, 0 );     
   if(ticket < 0) Print("Erro ao abrir ordem de venda: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| Função para calcular a média de volumes no array de candles      |
//+------------------------------------------------------------------+
double CalculateAverageVolume(int period)
  {
   double sum = 0;
   for(int i = 0; i < period; i++)
     {
      sum += roundPriceH9K(rates[i].tick_volume,price_step);
     }
   return sum / period;
  }
