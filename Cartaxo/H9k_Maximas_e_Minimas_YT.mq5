//+------------------------------------------------------------------+
//|                                     H9k_maximas_e_minimas_yt.mq5
//|                                              H9k Trading Systems
//|                               https://www.youtube.com/@h9ktrades
//+------------------------------------------------------------------+

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>
#define     MName          "H9k Automações e Eduçãcao Financeira"
#define     MVersion       "1.01"
#define     MCopyright     "Copyright \x00A9 2025, Rodolfo Sikora, All rights reserved"
#define     MProfile       "https://www.youtube.com/@h9ktrades"
#define     MCommentCode   "RC1"

#property   strict
#property   version        MVersion
#property   description    MName
#property   copyright      MCopyright
#property   link           MProfile

input ulong  iMagicNumber    = 20250118;
input double iAmount         = 1;
input bool   iReversion      = true;
input bool   iUseFixedTarget = true;
input double iFixedTarget    = 300;

MqlRates rates[];
double vHigh, vLow, vTarget;
datetime vStartTime;
bool vAllowTrade = true;
bool vSetReversionOrders = false;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

    trade.SetExpertMagicNumber(iMagicNumber);
    
    ArraySetAsSeries(rates, true);
        
    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, "h9k_line_", 0, -1);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {    
    
    MqlDateTime setTime;
    datetime currentTime = TimeCurrent();
    TimeToStruct(currentTime, setTime);
    setTime.hour = 9;
    setTime.min = 5;
    setTime.sec = 0;
    vStartTime = StructToTime(setTime);

    if (currentTime < vStartTime) {
        setMaxMin();
        
        if (!iUseFixedTarget) {
            vTarget = vHigh - vLow;
        } else {
            vTarget = iFixedTarget;
        }
        
        vAllowTrade = true;
        vSetReversionOrders = false;
        //PlotN("h9k_line_high", vHigh, clrYellow);
        //PlotN("h9k_line_low", vLow, clrBrown);
        //ChartRedraw();
        return;
    }
    
    int _total_positions = HasPosition(iMagicNumber);
    
    if(_total_positions == 0 && vSetReversionOrders) {
       closeAllOpenOrders();
    }
    
    if (_total_positions == 1 && !vSetReversionOrders) {
        CPositionInfo  _pos;
        
        
        
        if(_pos.Magic() == iMagicNumber  && _pos.PositionType() == POSITION_TYPE_BUY && _pos.Volume() == iAmount) {
            closeSellStopOrders();
            if (iReversion)
                trade.SellStop(iAmount + 2*iAmount, _pos.StopLoss(), _Symbol, _pos.PriceOpen(), _pos.StopLoss() - vTarget, ORDER_TIME_DAY, 0, "Rompimento da máxima");
        } else if (_pos.Magic() == iMagicNumber  && _pos.PositionType() == POSITION_TYPE_SELL && _pos.Volume() == iAmount) {
            closeBuyStopOrders();
            if (iReversion)
                trade.BuyStop(iAmount + 2*iAmount, _pos.StopLoss(), _Symbol, _pos.PriceOpen(), _pos.StopLoss() + vTarget, ORDER_TIME_DAY, 0, "Rompimento da máxima");
        }
        
        vSetReversionOrders = true;
        
    } else if (vAllowTrade) {
        trade.SellStop(iAmount, vHigh, _Symbol, vLow, vHigh + vTarget, ORDER_TIME_DAY, 0, "Rompimento da máxima");
        trade.BuyStop(iAmount, vLow, _Symbol, vHigh, vLow - vTarget, ORDER_TIME_DAY, 0, "Rompimento da máxima");
        vAllowTrade = false;
    }
}

void closeAllOpenOrders() {
    if (OrdersTotal() > 0) {
        for(int i = OrdersTotal(); i >= 0; i--) {
            ulong ticket = OrderGetTicket(i);
            if(OrderGetInteger(ORDER_MAGIC) != iMagicNumber) continue;
            trade.OrderDelete(ticket);
        }
    }
}

void closeBuyStopOrders() {
    if (OrdersTotal() > 0) {
        for(int i = OrdersTotal(); i >= 0; i--) {
            ulong ticket = OrderGetTicket(i);
            if(OrderGetInteger(ORDER_MAGIC) != iMagicNumber) continue;
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) {
                trade.OrderDelete(ticket);
            }
        }
    }
}

void closeSellStopOrders() {
    if (OrdersTotal() > 0) {
        for(int i = OrdersTotal(); i >= 0; i--) {
            ulong ticket = OrderGetTicket(i);
            if(OrderGetInteger(ORDER_MAGIC) != iMagicNumber) continue;
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) {
                trade.OrderDelete(ticket);
            }
        }
    }
}

void setMaxMin() {    
        
    // Calcular o início do dia (00:00) no fuso horário do servidor
    MqlDateTime setTime;
    datetime currentTime = TimeCurrent();
    TimeToStruct(currentTime, setTime);
    datetime startOfDay = currentTime - (currentTime % 86400);    
    setTime.hour = 9;
    setTime.min = 5;
    setTime.sec = 0;
    
    //PrintFormat("stard: %s end: %s", (string)startOfDay, (string)StructToTime(setTime));

    int _cp_rates = CopyRates(Symbol(), PERIOD_M1, startOfDay, StructToTime(setTime), rates);
    
    if (_cp_rates <= 0) {
        Print("Fala ao copiar cotações. Error ", GetLastError());
        return;
    }
    
    vHigh = 0;
    vLow  = 0;
    
    for(int i = 0; i < _cp_rates; i++) {        
        vHigh = rates[i].high > vHigh ? rates[i].high : vHigh;
        vLow  = (vLow == 0 || rates[i].low < vLow) ? rates[i].low : vLow;        
    }
    
}

void PlotN(string name, double price, color lineColor = clrYellow)
{
   // Verifica se a linha já existe
   if(ObjectFind(0, name) != -1)
   {
      // Atualiza o preço da linha horizontal existente
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);      
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   }
   else
   {
      // Cria uma nova linha horizontal se ela não existir
      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
      {
         Print("Erro ao criar a linha horizontal: ", GetLastError());
         return;
      }
      
      // Define a cor da linha
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);

      // Define a largura da linha (opcional)
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

      // Torna a linha visível em todas as janelas de tempo (opcional)
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   }
}