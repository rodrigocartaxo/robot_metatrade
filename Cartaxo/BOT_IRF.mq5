//+------------------------------------------------------------------+
//|                                       H9k_YT_GL_Hedge_1_5_yt.mq5 |
//|                                              H9k Trading Systems |
//|                               https://www.youtube.com/@h9ktrades |
//+------------------------------------------------------------------+

//TODO
//Implementar tamanho da grade pelo ATR

#property copyright "H9k Trading Systems"
#property link      "https://www.youtube.com/@h9ktrades"
#property version   "1.05"

#include <Trade\Trade.mqh>
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\H9k_Includes\H9k_Panels.mqh>


//--- input parameters
input group "Daytrade Window"
input bool   i24h = false; //Liga o modo 24h (forex)
input string iHoraIni = "09:05:00"; //Hora inicio
input string iHoraFim = "17:30:00"; //Hora fim
input int    iDailyTarget = 300;
input int    iLossTarget  = 300;

input group "Basic Settings"
input long   iMagicNumber   = 101;
input double iAmount        = 1;        //Quantidade de Contratos
input int    iMaxEntries    = 1;       //Quantidade de entradas do gradiente
input double iDistance      = 20;       //Distância entre as entradas
input double iGainDistance  = 100;       //Distância para take profit
input double iFirstGain     = 150;  
input bool   iClosePositions  = true;  //Botão de clear deve zerar posições

input group "Risk Management"
input double iDDTrigger = 500; // Valor para ativar o drawdown
input double iDrawDown  = 20;  // Percentual do valor para fechar posição

input group "IFR Parameters"
input int                   iIFRPeriod = 14;
input ENUM_TIMEFRAMES       iIFRTimeFrame = PERIOD_CURRENT;
input ENUM_APPLIED_PRICE    iIFRAppliedPrice = PRICE_CLOSE;
input int                   iBoughtIFR = 70;
input int                   iSoldIFR = 30;

input group "ATR Parameters"
input bool      iUseATR             = false;         //Usar cálculo do ATR em vez de pontos fixos para grade
input ENUM_TIMEFRAMES iATRTimeFrame = PERIOD_CURRENT;//Timeframe base do ATR
input int       iATRPeriod          = 14; 
input double    iStopATR            = 1.0;           //Multiplicador ATR p/ ser utilizado como stop
input double    iGridATR            = 0.5;           //Multiplicador ATR p/ ser utilizado como distância
input double    iTakeATR            = 1.5;           //Multiplicador ATR p/ ser utilizado como lucro primeira entrada

CTrade trade;
MqlRates rates[];

//int orders_sent;
double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick

//BB variables
int hATR; //handler do buffer do ATR
int hIFR; //handler do buffer do RSI/IFR

bool vOrderPlaced = false; //Para registra se a ordem já foi enviada ou não
bool vTPTrigger = false;
bool newBar; //Para saber se estamos em uma nova barra

double vATR[];
double vIFR[]; //Array para armazenar os valores do IFR

double entry_price, stop_loss, vMaxProfit;
datetime entry_time;
bool force_sell, force_buy; // variáveis de controle liga/desliga de compra e venda manual
bool vPauseEA = false;      // variável de controle para pausar/iniciar estratégia
bool vTargetLock = false;
bool vDDTriggerActive = false;
string global_last_entry, global_last_time; //Variáveis que contém os nomes das variáveis globais.

//variáveis para controle do painel de comentários
string panel_items[] = {"Status:", "Magic:", "Entry Price:", "Result:", "Position ($):", "Total:", "Open pos.:", "Avg. Price:", "Max Loss:", "Daily Result:", 
                        "Week Result:", "Month Result", "ATR:" ,"IFR[0]","IFR[1]" };
string panel_values[];

double valorAberto, valor_recebido;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("inicializando...");
   
    global_last_entry = StringFormat("GL_HEDGE_last_entry_point_%s", (string)iMagicNumber);
    global_last_time  = StringFormat("GL_HEDGE_last_time_point_%s", (string)iMagicNumber);
    
   

    if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
        Print("Este EA só pode ser executado em contas em modo HEDGE.");
        return INIT_FAILED;
    }

    double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    if(iAmount < min_volume) {
        PrintFormat("Volume é menor do que o mínimo permitido SYMBOL_VOLUME_MIN=%.2f", min_volume);
    }

    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(vATR, true);
    ArraySetAsSeries(vIFR, true);

    ArrayResize(panel_values, ArraySize(panel_items));

    hATR = iATR(_Symbol, iATRTimeFrame, iATRPeriod);
    if(hATR < 0) return INIT_FAILED;
    
    hIFR = iRSI(_Symbol, iIFRTimeFrame, iIFRPeriod, iIFRAppliedPrice);
    if(hIFR < 0) return INIT_FAILED;
      
    if(has_open_order(iMagicNumber) > 0)
        vOrderPlaced = true;
    else
        vOrderPlaced = false;

    vMaxProfit = 0;
    trade.SetExpertMagicNumber(iMagicNumber);

    //Bloco de leitura das variáveis globais
    if (HasPosition(iMagicNumber) == 0) {
        GlobalVariableDel(global_last_entry);
        GlobalVariableDel(global_last_time);
    } else if(HasPosition(iMagicNumber) > 0) {
        double stime;
        GlobalVariableGet(global_last_entry, entry_price);
        GlobalVariableGet(global_last_time, stime);
        entry_time = (datetime)stime;
        Print("Reading global entry price: ", entry_price);
        Print("Reading global entry time: ", entry_time);
    }

    //Inicialização do Painel
    panel_values[0]  = "Initializing...";
    panel_values[1]  = (string)iMagicNumber;
    panel_values[2]  = "-";
    panel_values[3]  = (string)DailyResult(iMagicNumber, entry_time);
    panel_values[4]  = (string)OpenResult(iMagicNumber);
    panel_values[5]  = (string)(DailyResult(iMagicNumber, entry_time) + OpenResult(iMagicNumber));
    panel_values[6]  = "-";
    panel_values[7]  = "-";
    panel_values[7]  = "-";
    panel_values[8]  = (string)simpleCalculateMaxLoss(_Symbol, iMaxEntries, iDistance, iAmount);
    panel_values[9]  = (string)(DailyResult(iMagicNumber) + OpenResult(iMagicNumber));
    panel_values[10] = (string)weeklyResult(iMagicNumber);
    panel_values[11] = (string)monthlyResult(iMagicNumber);
    panel_values[12] = "-";
    panel_values[13] = "-";
    panel_values[14] = "-";

    createPanel(250, 350);
    populatePanel(panel_items, panel_values);

    createButtons(12, 310);
    
    if((DailyResult(iMagicNumber) + OpenResult(iMagicNumber)) <= 0.95*iDailyTarget) {
        vTargetLock = false;
    }

    PrintFormat("[%d] Inicializado com sucesso!", iMagicNumber);
    
    EventSetTimer(1);

    return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
        
    if(hIFR != INVALID_HANDLE)
        IndicatorRelease(hIFR);
        
    if(hATR != INVALID_HANDLE)
        IndicatorRelease(hATR);

    ObjectsDeleteAll(0, "myButton_", 0, -1);

    saveGlobals();
    destroyPanel();

    force_buy = false;
    force_sell = false;

    EventKillTimer();
    
    PrintFormat("[%d] desligando.", iMagicNumber);
}

void OnTimer(){

    if (CopyBuffer(hATR, 0, 0, 3, vATR) <= 0) return;
    if (CopyBuffer(hIFR, 0, 0, 3, vIFR) <= 0) return;
    
    panel_values[8]  = (string)simpleCalculateMaxLoss(_Symbol, iMaxEntries, iDistance, iAmount);
    panel_values[9]  = DoubleToString(DailyResult(iMagicNumber) + OpenResult(iMagicNumber), 2);
    panel_values[10] = DoubleToString(weeklyResult(iMagicNumber) + OpenResult(iMagicNumber), 2);
    panel_values[11] = DoubleToString(monthlyResult(iMagicNumber) + OpenResult(iMagicNumber), 2);    
    panel_values[12] = DoubleToString(vATR[0], _Digits); // + " (" + DoubleToString(spread, _Digits)+ ")";
    panel_values[13] = DoubleToString(vIFR[0], _Digits); // + " (" + DoubleToString(spread, _Digits)+ ")";
    panel_values[14] = DoubleToString(vIFR[1], _Digits); // + " (" + DoubleToString(spread, _Digits)+ ")";
    
 
    //Print("ddd",valor_recebido);
}


//+------------------------------------------------------------------+
//| Expert tick function
//+------------------------------------------------------------------+
void OnTick()
{
    newBar = isNewBar();

    int open_positions = HasPosition(iMagicNumber);
    int open_orders    = OpenOrdersCount(iMagicNumber);
    
    double l_result = DailyResult(iMagicNumber) + OpenResult(iMagicNumber);
    
    panel_values[2] = DoubleToString(entry_price, _Digits);
    panel_values[3] = entry_time ? (string)DailyResult(iMagicNumber, entry_time) : "0";
    panel_values[4] = DoubleToString(OpenResult(iMagicNumber), 2);
    panel_values[5] = entry_time ? DoubleToString(DailyResult(iMagicNumber, entry_time) + OpenResult(iMagicNumber), 2) : "0";
    panel_values[6] = (string)HasPosition(iMagicNumber);
    panel_values[7] = (string)PositionsAveragePrice(iMagicNumber);
    
    if(open_orders + open_positions == 0) {
        entry_time = 0; //para ajustar o painel com valores corretos   
    }
    if(GlobalVariableCheck("vTargetLock_global")){
      
      if (GlobalVariableGet("vTargetLock_global")){
         panel_values[0]="Bloqueado Global";
         populatePanel(panel_items, panel_values);
         closeAllPositions(trade, iMagicNumber);
         closeAllOpenOrders(trade, iMagicNumber);        
         vTargetLock = false;
         vDDTriggerActive = false;
        return;
      }
     }
      
    if (!i24h && !allowed_by_hour(iHoraIni, iHoraFim)) {
        panel_values[0] = "Sleeping...";
        closeAllPositions(trade, iMagicNumber);
        closeAllOpenOrders(trade, iMagicNumber);        
        populatePanel(panel_items, panel_values);
        vTargetLock = false;
        vDDTriggerActive = false;
        return;
    }
    
    if(vTargetLock == true) {
        closeAllOpenOrders(trade, iMagicNumber);
        closeAllPositions(trade, iMagicNumber);        
        return;
    }
    
    //Comment("VDDTrigger: ", vDDTriggerActive);
    
    if(l_result >= iDDTrigger) {
        if(!vDDTriggerActive) PrintFormat("[%d] Drawdown trigger activated (%.2f).", iMagicNumber, l_result);

        vDDTriggerActive = true;
        if (vMaxProfit < l_result) vMaxProfit = l_result;        
    }
    
    if(vDDTriggerActive && l_result <= (1 - iDrawDown/100)*vMaxProfit) {
        panel_values[0] = "Drawdown achieved!";
        PrintFormat("[%d] Drawdown %.2f achieved (%.2f / %.2f).", iMagicNumber, iDrawDown, vMaxProfit, l_result);
        closeAllOpenOrders(trade, iMagicNumber);
        closeAllPositions(trade, iMagicNumber); 
        populatePanel(panel_items, panel_values);
        vTargetLock = true;
        return;
    }

    if(l_result >= iDailyTarget) {
        panel_values[0] = "Target achieved!";
        closeAllOpenOrders(trade, iMagicNumber);
        closeAllPositions(trade, iMagicNumber);        
        populatePanel(panel_items, panel_values);
        vTargetLock = true;
        return;
    }
    
    if((DailyResult(iMagicNumber) + OpenResult(iMagicNumber)) <= -1 * iLossTarget) {
        panel_values[0] = "Perda máxima :(";
        closeAllOpenOrders(trade, iMagicNumber);
        closeAllPositions(trade, iMagicNumber);        
        populatePanel(panel_items, panel_values);
        vTargetLock = true;
        return;
    }

    saveGlobals();

    if (vPauseEA) {
        closeAllOpenOrders(trade, iMagicNumber);
        if(!has_open_order(iMagicNumber))
            vOrderPlaced = false;
            
        if(iClosePositions && HasPosition(iMagicNumber)) {
            closeAllPositions(trade, iMagicNumber);
        }

        panel_values[0] = "EA on hold";
        populatePanel(panel_items, panel_values);

        return;
    } else if (vTPTrigger && open_positions == 0) { //aqui ele atingiu o alvo máximo, vai fechar todas as ordens
        closeAllOpenOrders(trade, iMagicNumber);        
    }

    panel_values[0] = "running...";
    populatePanel(panel_items, panel_values);

   //Coloca o valor dos 3 últimos candles na variável "rates" do tipo array
    int copied  = CopyRates(_Symbol, _Period, 0, 3, rates);
    if(copied <= 0) return; //Caso não consiga pegar as cotações, retorna

    //atualizando o valor do ATR
    if (CopyBuffer(hATR, 0, 0, 3, vATR) <= 0) return;
    if (CopyBuffer(hIFR, 0, 0, 3, vIFR) <= 0) return;

    open_positions = HasPosition(iMagicNumber);
    open_orders    = OpenOrdersCount(iMagicNumber);
      
    double target = vATR[0] * 1.5; 


    bool isBuy  =   vIFR[0] < iSoldIFR && vIFR[1] < iSoldIFR;
                  
    bool isSell =  vIFR[0] > iBoughtIFR  && vIFR[1] > iBoughtIFR ;

    entry_price = roundPriceH9K(rates[1].close , price_step);
    
    
    if (isBuy && HasPosition(iMagicNumber) == 0 && !vOrderPlaced) {
        
       printf("target vATR[0] %2f ",DoubleToString(vATR[0], _Digits));
       printf("target %2f",target);
       
       //stop_loss = roundPriceH9K(entry_price - target, price_step);
       stop_loss = roundPriceH9K(entry_price - iMaxEntries*iDistance, price_step);
        for (int i = 0; i < iMaxEntries; i++) {

            double order_price = entry_price - (i * iDistance);

            if (i == 0) {
                trade.BuyLimit(iAmount, %2f, _Symbol, stop_loss, order_price + iFirstGain, ORDER_TIME_DAY, 0, "Ordem de compra "+(string)(i+1) +" limite.");
            } else {
                trade.BuyLimit(iAmount, order_price, _Symbol, stop_loss,  order_price + iGainDistance, ORDER_TIME_DAY, 0, "Ordem de compra "+(string)(i+1) +" limite.");                
            }
        }

        entry_time = TimeTradeServer();
        vOrderPlaced = true;
        force_buy = false; //não permitir reentrada automática

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
    } else if (isSell && HasPosition(iMagicNumber) == 0 && !vOrderPlaced) { //Montagem inicial da grade na ponta vendida
       
        printf("target %2f",target);
       //stop_loss = roundPriceH9K(entry_price - target, price_step);
       stop_loss = roundPriceH9K(entry_price - iMaxEntries*iDistance, price_step);

        for(int i = 0; i < iMaxEntries; i++) {
            double order_price =  entry_price + (i * iDistance);
            if (i == 0) {
                trade.SellLimit(iAmount, order_price, _Symbol, stop_loss,  order_price - iFirstGain, ORDER_TIME_DAY, 0, "Ordem venda "+(string)(i+1) +" limite.");
            } else {
                trade.SellLimit(iAmount, order_price, _Symbol, stop_loss,  order_price - iGainDistance, ORDER_TIME_DAY, 0, "Ordem venda "+(string)(i+1) +" limite.");
            }

        }

        entry_time = TimeTradeServer();
        vOrderPlaced = true;
        force_sell = false; //não permitir reentrada automática

    }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    CDealInfo m_deal;

    ENUM_ORDER_STATE lastOrderState = trans.order_state;

    switch(trans.type) {
    case TRADE_TRANSACTION_HISTORY_ADD: { // adição da ordem ao histórico
        //--- identificador da transação no sistema externo - bilhete atribuído pela bolsa
        string Exchange_ticket="";
        if(lastOrderState==ORDER_STATE_FILLED) {
            //Print("Ordem executada");
        } else if (lastOrderState == ORDER_STATE_CANCELED) {
            //Print("Ordem cancelada");
        }
    }
    break;
    case TRADE_TRANSACTION_DEAL_ADD: {
        if(HistoryDealSelect(trans.deal))
            m_deal.Ticket(trans.deal);
        else {
            Print(__FILE__," ",__FUNCTION__,", ERROR: HistoryDealSelect(",trans.deal,")");
            return;
        }

        long reason=-1;
        if(!m_deal.InfoInteger(DEAL_REASON,reason)) {
            Print(__FILE__," ",__FUNCTION__,", ERROR: InfoInteger(DEAL_REASON,reason)");
            return;
        }
        if (m_deal.Magic() == iMagicNumber) {
            if((ENUM_DEAL_REASON)reason==DEAL_REASON_SL)
                Print("Stop Loss activation");
            else if((ENUM_DEAL_REASON)reason == DEAL_REASON_TP)
                vTPTrigger = true; //só libera para repor quando tem TP
        }
    }
    break;
    }
}

//+------------------------------------------------------------------+
//| Captura eventos do gráfico - botões                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    
    if(sparam == "myButton_Clear" && lparam > 0) {
        if (!vPauseEA) {
            vPauseEA = true;
            force_buy = false;
            force_sell = false;
            vTPTrigger = false;
            Print("Clearing and pausing");
            ObjectSetString(0, "myButton_Clear",OBJPROP_TEXT,"Start EA");
        } else {
            vPauseEA = false;
            Print("Let it go...");
            ObjectSetString(0, "myButton_Clear",OBJPROP_TEXT,"Clear & Pause");
        }
        ChartRedraw(0);
        Sleep(200);
     
    } 
}

//+------------------------------------------------------------------+
//| Criação dos botões de negociação                                 |
//+------------------------------------------------------------------+
void createButtons(int l_x, int l_y)
{
    ObjectCreate(0, "myButton_Clear",OBJ_BUTTON,0,0,0);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_XDISTANCE, l_x);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_YDISTANCE, l_y);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_XSIZE,235);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_YSIZE,50);
    ObjectSetString(0, "myButton_Clear",OBJPROP_TEXT,"Clear & Pause");
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_COLOR, C'255,240,245');
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_BGCOLOR, C'64,60,66');
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_BORDER_COLOR,C'64,60,66');
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_BORDER_TYPE,BORDER_FLAT);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_BACK, false);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_STATE, false);
    ObjectSetInteger(0, "myButton_Clear",OBJPROP_FONTSIZE, 12);

    

    ChartRedraw(0);
    Sleep(200);
}

//+------------------------------------------------------------------+
//| Função para salvar variáveis globais
//+------------------------------------------------------------------+
void saveGlobals()
{
    if(HasPosition(iMagicNumber) > 0) {
        //Print("Setting global entry price: ", entry_price);
        //Print("Setting global entry time: ", entry_time);
        GlobalVariableSet(global_last_entry, entry_price);
        GlobalVariableSet(global_last_time, (double)entry_time);
    }
}

//+------------------------------------------------------------------+
