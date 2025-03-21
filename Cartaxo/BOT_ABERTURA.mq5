//+------------------------------------------------------------------+
//|                                                 H9K_MT5_JUST.mq5 |
//|                                              H9k Trading Systems |
//|                               https://www.youtube.com/@h9ktrades |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>

input double RiskRewardRatio    = 2; // Relação risco/recompensa
input double iAmmout            = 1; // Tamanho do lote
input long   iMagicNumber       = 12540;
input string iHoraIni = "09:00:00"; //Hora inicio
input string iHoraFim = "17:30:00"; //Hora fim
input double PercentualGapGo  = 0.10;
input double PercentualNGapGo = 0.50;
input int iDistance = 20; // Distancia



CTrade ctrade;
MqlRates rates[];
double price_step = SymbolInfoDouble ( Symbol(), SYMBOL_TRADE_TICK_SIZE );





//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
    ArraySetAsSeries(rates, true);
    ctrade.SetExpertMagicNumber(iMagicNumber);
    PrintFormat("[%d] Ligando....", iMagicNumber);
    
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  
   PrintFormat("[%d] desligando.", iMagicNumber);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!allowed_by_hour(iHoraIni, iHoraFim)) {
        closeAllPositions(ctrade, iMagicNumber);
        closeAllOpenOrders(ctrade, iMagicNumber); 
        return;       
    }
    
       
    
    double fechamentoDiaAnterior = iClose(_Symbol, PERIOD_D1, 1);
        
    // Obter o preço de abertura da primeira barra de 1 minuto do dia
    double aberturaPrimeiraBarra = iOpen(_Symbol, PERIOD_M1, 0);
   
    int pGap = MathAbs((int)(fechamentoDiaAnterior - aberturaPrimeiraBarra));
    double perce = round(pGap/fechamentoDiaAnterior*100) ;
    
    /*PrintFormat(" fechamentoDiaAnterior."+ fechamentoDiaAnterior);
    PrintFormat(" aberturaPrimeiraBarra."+ aberturaPrimeiraBarra);
    PrintFormat(" pGap."+ pGap);
    PrintFormat(" perce."+ perce); */
          
    CopyRates(Symbol(), PERIOD_CURRENT, 0, 3, rates);

    
    double sell_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double buy_price  =  SymbolInfoDouble(_Symbol, SYMBOL_BID); 
    
    bool isBuyGapGo = (pGap > PercentualGapGo) && (pGap < PercentualNGapGo && pGap < 0);
    bool isSellGapGo = (pGap > PercentualGapGo)&& ( pGap < PercentualNGapGo) && (pGap > 0);
    
    bool isBuyNGapGo =  (pGap> PercentualNGapGo) && (pGap < 0);
    bool isSellNGapGo = (pGap> PercentualNGapGo) && (pGap > 0);
    
    if (!isNewBar()) return;
    
    if (!isFirstBarOfDay()){
         Comment(" nao é a primeria barra do dia [%d].",iMagicNumber);
         return;
    }
    
    if (!has_open_order(iMagicNumber)) return;
    
    
    
    PrintFormat(" fechamentoDiaAnterior. [%2f] ", fechamentoDiaAnterior);
    PrintFormat(" aberturaPrimeiraBarra [%2f]", aberturaPrimeiraBarra);
    PrintFormat(" pGap [%2f]", pGap);
    PrintFormat(" perce [%2f]", perce); 
    
    
    
    if (isBuyGapGo ||isBuyNGapGo ){
      double stop_loss = buy_price - iDistance * price_step ;
      double take_profit = buy_price + iDistance * RiskRewardRatio * price_step;

     int ticket = ctrade.BuyLimit(iAmmout, buy_price, _Symbol, stop_loss, take_profit, ORDER_TIME_DAY, 0);
     if(ticket < 0) Print("Erro ao abrir ordem de compra: ", GetLastError());
    
    }else if (isSellGapGo || isSellNGapGo){
    
     double stop_loss = sell_price + iDistance * price_step;
     double take_profit = sell_price - iDistance * RiskRewardRatio * price_step;
   
      int ticket = ctrade.SellLimit(iAmmout, sell_price, _Symbol, stop_loss, take_profit, ORDER_TIME_DAY, 0 );     
      if(ticket < 0) Print("Erro ao abrir ordem de venda: ", GetLastError());
    }
    

}
bool isFirstBarOfDay()
  {
   datetime current_bar_time = iTime(_Symbol, PERIOD_M2, 0); // Horário da barra atual
   datetime previous_bar_time = iTime(_Symbol, PERIOD_M1, 1); // Horário da barra anterior

   MqlDateTime current_bar_date, previous_bar_date;

   // Converter os horários para estruturas de data
   TimeToStruct(current_bar_time, current_bar_date);
   TimeToStruct(previous_bar_time, previous_bar_date);

   // Se o dia da barra atual for diferente do dia da barra anterior, é a primeira barra do dia
   if(current_bar_date.day != previous_bar_date.day)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
