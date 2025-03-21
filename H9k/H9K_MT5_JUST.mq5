//+------------------------------------------------------------------+
//|                                                 H9K_MT5_JUST.mq5 |
//|                                              H9k Trading Systems |
//|                               https://www.youtube.com/@h9ktrades |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#include <./H9k_Includes/H9k_YT_libs_3.mqh>

input double amount = 1; //Volume OP
input double iVariation  = 1.30;   // Variação em percentual
input double iStopLoss   = 0.50;    // Loss em percentual
input double iRiskReturn = 2;    // Retorno / Risco (2 = ganha o dobro do que perde)
input ENUM_TIMEFRAMES working_period = PERIOD_D1;  //Período do gráfico em análise
input ENUM_APPLIED_PRICE reference = PRICE_CLOSE;
input long   iMagicNumber       = 562252;


CTrade ctrade;
MqlRates rates[];
double price_step = SymbolInfoDouble ( Symbol(), SYMBOL_TRADE_TICK_SIZE );


void closeAllOpenOrders(string symbol, CTrade & ltrade)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetString(ORDER_SYMBOL) == symbol) {
            ltrade.OrderDelete(ticket);
        }
    }
}

void closeAllOpenPositions(CTrade & ltrade)
{
  for(int i = PositionsTotal(); i >= 0; i--) {
    ulong ticket = PositionGetTicket(i);
    ltrade.PositionClose(ticket);
     
    //Print("Day trade stopped by time");
  }
}



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
    ArraySetAsSeries(rates, true);
    ctrade.SetExpertMagicNumber11(iMagicNumber);
    
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
    if(!allowed_by_hour("09:00:00", "17:30:00")) {
        Comment("Not allowed by Time.");
        // se tiver posição em aberto, fechar
        closeAllOpenPositions(ctrade);
        return;
    }
    
    double fechamentoDiaAnterior = iClose(_Symbol, PERIOD_D1, 1);
        
    // Obter o preço de abertura da primeira barra de 1 minuto do dia
    double aberturaPrimeiraBarra = iOpen(_Symbol, PERIOD_M1, 0);
   
    int pGap = MathAbs((int)(fechamentoDiaAnterior - aberturaPrimeiraBarra));
    double perce =  MathAbs((pGap/fechamentoDiaAnterior)*100) ;
    
    /*PrintFormat(" fechamentoDiaAnterior."+ fechamentoDiaAnterior);
    PrintFormat(" aberturaPrimeiraBarra."+ aberturaPrimeiraBarra);
    PrintFormat(" pGap."+ pGap);
    PrintFormat(" perce."+ perce); */
          
    CopyRates(Symbol(), working_period, 0, 3, rates);

    price_step = 0.5;

    double sell_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);//rates[0].close;//roundPriceH9K(rates[1].close * (1 + iVariation/100), price_step);
    double buy_price  =  SymbolInfoDouble(_Symbol, SYMBOL_BID); //rates[0].close;//roundPriceH9K(rates[1].close * (1 - iVariation/100), price_step);
    
    
    if(PositionSelect(_Symbol) ==  false && OrdersTotal() == 0 && rates[0].close < sell_price && rates[0].close > rates[1].close) {

        closeAllOpenOrders(_Symbol, ctrade);

        
        
        double sl_pts = roundPriceH9K((sell_price * iStopLoss/100),price_step);
        double tp_pts = roundPriceH9K((sell_price * iRiskReturn * iStopLoss/100),price_step);
        double sl = sell_price + sl_pts;
        double tp = sell_price - tp_pts;

        ctrade.SellLimit(amount, sell_price, _Symbol, sl, tp, ORDER_TIME_DAY, 0, "Sell Variação close + " + DoubleToString(iVariation) + "%");

    } else if(PositionSelect(_Symbol) ==  false && OrdersTotal() == 0 && rates[0].close > buy_price && rates[0].close < rates[1].close) {
        closeAllOpenOrders(_Symbol, ctrade);

        double sl_pts = roundPriceH9K((buy_price * iStopLoss/100),price_step);
        double tp_pts = roundPriceH9K((buy_price * iRiskReturn * iStopLoss/100),price_step);
        double sl = buy_price - sl_pts;
        double tp = buy_price + tp_pts;

        ctrade.BuyLimit(amount, buy_price, _Symbol, sl, tp, ORDER_TIME_DAY, 0, "Buy Variação close + " + DoubleToString(iVariation) + "%");
    }

}
//+------------------------------------------------------------------+
