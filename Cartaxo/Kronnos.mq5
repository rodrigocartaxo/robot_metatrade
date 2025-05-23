

#property version   "1.01"

#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <Trade\Trade.mqh>
#include <.\MyPainel.mqh>
#include <.\MyMagicNumber.mqh>


//--- input parameters
 

input group "Basic Settings"
input int    iMaxAmount = 50;      //Máxima quantidade de contratos posicionados
input int    iRangePoints = 30;     // Range in Points for Pending Orders

input group "Take Profit and Stop Loss Settings"
input double iTPPoints = 40;  // Take Profit in Points

CTrade trade;
MqlRates rates[];

bool vOrderPlaced = false; //variável para controlar se posso ou não mandar novas ordens
bool EnableSell   = false;
bool EnableBuy    = false;
bool pause        = false;

bool AllowBuy  = false;
bool AllowSell = false;

bool position_alert = false;

bool newBar; //Para saber se estamos em uma nova barra
double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick

double iAmount    = 1;      //Quantidade de Contratos
ulong   iMagic     = 0; //Magic Number

MyPainel painel;
MyMagicNumber myMagicNumber;

string sep = ",";
string V_Currencies[];




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("inicializando...");

    if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
        Print("Este EA só pode ser executado em contas em modo HEDGE.");
        return INIT_FAILED;
    }

    ArraySetAsSeries(rates, true);
    
  
    
    iMagic = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),currencies);
    trade.SetExpertMagicNumber(iMagic);
   
    if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
    
    Sleep(200);
    ChartRedraw(0);
    EventSetTimer(1);  
    Print("Inicializado com sucesso!");

    return(INIT_SUCCEEDED);
}
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );
   
}
void OnTimer(){
   painel.OnTimer();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0,"myButton_",0,-1);
    Sleep(200);
    ChartRedraw(0);
    EventKillTimer();
    painel.Destroy(reason);
     
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    newBar = isNewBar();
    painel.OnTick();
    ushort sep_code = StringGetCharacter(sep,0);
    StringSplit(currencies,sep_code,V_Currencies);
    for(int i=ArraySize(V_Currencies)-1;i>=0;i-- ){
       
       string symbol =   V_Currencies[i];
      // printf(symbol);
        iAmount = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)+iRangeLotes;
    
       if (pause) {
           trade.PositionClose(symbol);
           closePendingOrders(symbol,trade, iMagic );  // Use a função da biblioteca
           EnableSell = false;
           EnableBuy  = false;
           AllowBuy   = false;
           AllowSell  = false;
           position_alert = false;
           
           Comment("Paused");
           while(has_open_order(iMagic,NULL,symbol)) {
               Sleep(300);
           }
           
           vOrderPlaced = false;
           
           return;
       }    
   
       if(newBar && HasPosition(iMagic,symbol) == 0) {
           closePendingOrders(symbol,trade, iMagic );  // Use a função da biblioteca
           if(!has_open_order(iMagic,NULL,symbol)) {
               vOrderPlaced = false;
               EnableSell = false;
               EnableBuy = false;
               AllowBuy = false;
               AllowSell = false;
           }
       }
       
       if (HasPosition(iMagic,symbol) > 4) {
           position_alert = true;
           Alert("Martingale com mais de uma posição, corra para as montanhas.");    
       }
       
       if (position_alert) {
           closeAllOpenOrders(trade, iMagic,NULL,NULL);  // Use a função da biblioteca
           return;
       }
       
       int copied  = CopyRates(symbol, iTradeTimeFrame, 0, 2, rates);
       if(copied <= 0) return; // If couldn't fetch rates, exit
   
       // Criando um range a partir do fechamento da barra anterior
       double rangeSize = iRangePoints * price_step; // Define o tamanho do range em pontos
       double prevClose = rates[1].close; // Fechamento da barra anterior
   
       // Definindo os pontos para as ordens pendentes
       double sellPrice = prevClose - rangeSize; // Parte inferior do range para venda
       double buyPrice = prevClose + rangeSize;  // Parte superior do range para compra
       
        string msg =  MQLInfoString(MQL_PROGRAM_NAME)+ ": "+ symbol;
   
       // Colocando ordens pendentes
       if(!vOrderPlaced && HasPosition(iMagic,symbol) == 0) {
           MqlTick last_tick;
           if(!SymbolInfoTick(symbol, last_tick)) return;
   
           // Colocando ordem de venda pendente
           double stop_loss = buyPrice;  // Stop Loss da venda no preço de Buy Stop
           double take_profit = sellPrice - (iTPPoints * price_step);
           if (sellPrice < last_tick.ask && stop_loss > sellPrice && take_profit < sellPrice) {
               if(trade.SellStop(iAmount, sellPrice, symbol, stop_loss, take_profit, ORDER_TIME_DAY,0,msg)) {
                   EnableSell = true;
                   AllowBuy = true;  // Ativa Martingale para compra caso seja necessário
               } else {
                   Print("Sell Stop order failed, error: ", trade.ResultRetcodeDescription());
               }
           }
   
           // Colocando ordem de compra pendente
           stop_loss = sellPrice;  // Stop Loss da compra no preço de Sell Stop
           take_profit = buyPrice + (iTPPoints * price_step);
           if (buyPrice > last_tick.bid && stop_loss < buyPrice && take_profit > buyPrice) {
               if(trade.BuyStop(iAmount, buyPrice, symbol, stop_loss, take_profit, ORDER_TIME_DAY,0,msg)) {
                   EnableBuy = true;
                   AllowSell = true; // Ativa Martingale para venda caso seja necessário
               } else {
                   Print("Buy Stop order failed, error: ", trade.ResultRetcodeDescription());
               }
           }
   
           if(EnableSell || EnableBuy) {
               vOrderPlaced = true;
           }
       }
   
       // Lógica de Martingale para posições já abertas
       if(HasAndSelectSinglePosition(iMagic,symbol)) {
           double pos_vol = PositionGetDouble(POSITION_VOLUME);
   
           if(pos_vol >= iMaxAmount)
               return;
   
           if(IsSold(iMagic) && AllowBuy) {
               // Cancela a ordem pendente de compra antes de colocar a nova ordem de Martingale
               if (EnableBuy) {
                   closePendingOrders(symbol, trade, iMagic, ORDER_TYPE_BUY_STOP);
                   EnableBuy = false;
               }
   
               double new_entry_price = PositionGetDouble(POSITION_SL);
               double new_stop = PositionGetDouble(POSITION_PRICE_OPEN);
               double take_profit = new_entry_price + iTPPoints * price_step;
   
               Print("Martingale Buy Stop - Entry Price: ", new_entry_price, ", Stop Loss: ", new_stop, ", Take Profit: ", take_profit);
               if (new_entry_price > 0 && take_profit > new_entry_price && new_stop < new_entry_price) {
                   if(trade.BuyStop(pos_vol * 2, new_entry_price, symbol, new_stop, take_profit, ORDER_TIME_DAY,0,msg)) {
                       AllowBuy = false;
                       AllowSell = true;
                   } else {
                       Print("Martingale Buy Stop order failed, error: ", trade.ResultRetcodeDescription());
                   }
               }
           } else if(IsBought(iMagic) && AllowSell) {
               // Cancela a ordem pendente de venda antes de colocar a nova ordem de Martingale
               if (EnableSell) {
                   closePendingOrders(symbol, trade, iMagic, ORDER_TYPE_SELL_STOP);
                   EnableSell = false;
               }
   
               double new_entry_price = PositionGetDouble(POSITION_SL);
               double new_stop = PositionGetDouble(POSITION_PRICE_OPEN);
               double take_profit = new_entry_price - iTPPoints * price_step;
   
               Print("Martingale Sell Stop - Entry Price: ", new_entry_price, ", Stop Loss: ", new_stop, ", Take Profit: ", take_profit);
               if (new_entry_price > 0 && take_profit < new_entry_price && new_stop > new_entry_price) {
                   if(trade.SellStop(pos_vol * 2, new_entry_price, symbol, new_stop, take_profit, ORDER_TIME_DAY,0,msg)) {
                       AllowBuy = true;
                       AllowSell = false;
                   } else {
                       Print("Martingale Sell Stop order failed, error: ", trade.ResultRetcodeDescription());
                   }
               }
           }
       }
   }       
       
}

// Função para fechar ordens pendentes específicas
void closePendingOrders(string symbol, CTrade &param_trade, long magic, ENUM_ORDER_TYPE type= NULL)
{
    for(int i=OrdersTotal()-1; i>=0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue; // Se o ticket não for válido, continuamos para o próximo
        
        if (type== NULL){
           if(OrderGetString(ORDER_SYMBOL) == symbol && OrderGetInteger(ORDER_MAGIC) == magic){
                   param_trade.OrderDelete(ticket);
               }
        }

        if(OrderGetString(ORDER_SYMBOL) == symbol && OrderGetInteger(ORDER_MAGIC) == magic && 
           (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)) {
            if(type == -1 || OrderGetInteger(ORDER_TYPE) == type)
            {
                param_trade.OrderDelete(ticket);
            }
        }
    }
}