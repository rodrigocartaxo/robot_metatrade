//+------------------------------------------------------------------+
//|                                       H9k_YT_GL_Hedge_1_8_yt.mq5 
//|                                              H9k Trading Systems 
//|                               https://www.youtube.com/@h9ktrades 
//+------------------------------------------------------------------+

/* Copyright (C) 2025 - H9k Trades 
 * Este programa é software livre; você pode redistribuí-lo e/ou 
 * modificá-lo sob os termos da Licença Pública Geral Menor GNU 
 * conforme publicada pela Free Software Foundation; 
 * na versão 3 da Licença, ou (a seu critério) qualquer versão posterior.
 *
 * Este programa é distribuído na esperança de que seja útil, 
 * mas SEM QUALQUER GARANTIA; sem mesmo a garantia implícita de 
 * COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM DETERMINADO FIM. 
 * Veja a Licença Pública Geral Menor GNU para mais detalhes.
 *
 * Você deve ter recebido uma cópia da Licença Pública Geral Menor GNU
 * junto com este programa; se não, veja <http://www.gnu.org/licenses/>.
 */

//TODO
//Implementar tamanho da grade pelo ATR
//Implementar aumento do stop
//Informação do stop na grade (onde supostamente está o stop financeiro)
//Entrada por horário
//Direção da operação (compra ou venda ou ambas)
//Montar grade parcialmente -- DONE

#property copyright "H9k Trading Systems"
#property link      "https://www.youtube.com/@h9ktrades"
#property version   "1.85"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <.\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\H9k_Includes\H9k_Panels.mqh>
#include <Indicators\Trend.mqh>

enum ENUM_STRATEGY {
    manual,             // Manual Entry
    bollinger,          // Bollinger Bands
    cruzamento_medias,  // Cruzamento de médias
    fibo,               // Fibonacci
    sniper_sell,        // Venda com preço fixo
    sniper_buy,         // Compra com preço fixo
    just,               // Modo Just 0.5 alpha
    stIFR               // IFR
};

enum ENUM_ON_OFF {
    enabled  = 1,       // Ativado
    disabled = 0        // Desativado
};

//--- input parameters
input group "Daytrade Window"
input ENUM_ON_OFF i24h = disabled; //Liga o modo 24h (forex)
input string iHoraIni  = "09:05:00"; //Hora inicio
input string iHoraFim  = "17:30:00"; //Hora fim

input group "Basic Settings"
input long   iMagicNumber       = 20240625;
input ENUM_STRATEGY iStrategy = manual; //Estratégia a ser utilizada
input double iAmount        = 1;        //Quantidade de Contratos
input int    iMaxEntries    = 10;       //Quantidade de entradas do gradiente
input int    iMaxPendOrders = 5;        //Máximo de ordens penduradas
input double iDistance      = 50;       //Distância entre as entradas
input double iGainDistance  = 50;       //Distância para take profit
input double iFirstGain     = 100;      //Distância para o take da primeira entrada
input ENUM_ON_OFF iMedioParaFrente = enabled;  //Liga ou desliga o médio para frente
input ENUM_ON_OFF iMFTurbo  = disabled; //Modo turbo do Médio para Frente
input ENUM_ON_OFF iClosePositions  = enabled;  //Botão de clear deve zerar posições

input group "Risk Management"
input int    iDailyTarget = 300;       // Meta de ganho da operação
input int    iLossTarget  = 300;       // Loss máximo da operação
input double iDDTrigger = 500;         // Valor para ativar o drawdown
input double iDrawDown  = 20;          // Percentual do valor para fechar posição
input bool   iIgnoreGridLoss = false;  // Se true ignora o stop da grade

input group "IFR Parameters"
input int                   iIFRPeriod = 14;
input ENUM_TIMEFRAMES       iIFRTimeFrame = PERIOD_CURRENT;
input ENUM_APPLIED_PRICE    iIFRAppliedPrice = PRICE_CLOSE;
input int                   iBoughtIFR = 80;
input int                   iSoldIFR = 20;

input group "Fibo primeiro candle"
input double iFibo = 0.61;
input ENUM_TIMEFRAMES iFiboTF = PERIOD_M5; //Timeframe do Fibonacci

input group "Bollinger Bands Parameters"
input int                iBandsPeriod = 20;                // Períodos da média
input int                iBandsShift = 0;                  // Deslocamento da banda
input double             iBandsDeviation = 2.0;            // Desvio Padrão
input ENUM_APPLIED_PRICE iBandsAppliedPrice = PRICE_CLOSE; // Preço de referência
input ENUM_TIMEFRAMES    iBandsTimeFrame = PERIOD_M5;      // Timeframe

input group "Médias Móveis"
input ENUM_TIMEFRAMES   iMMTimeFrame    = PERIOD_CURRENT;
input int               iMMFastPeriod   = 3;
input int               iMMSlowPeriod   = 6;

input group "ATR Parameters"
//input bool      iUseATR             = false;         //Usar cálculo do ATR em vez de pontos fixos para grade
input ENUM_TIMEFRAMES iATRTimeFrame = PERIOD_CURRENT;//Timeframe base do ATR
input int       iATRPeriod          = 14; 
//input double    iStopATR            = 1.0;           //Multiplicador ATR p/ ser utilizado como stop
//input double    iGridATR            = 0.5;           //Multiplicador ATR p/ ser utilizado como distância
//input double    iTakeATR            = 1.5;           //Multiplicador ATR p/ ser utilizado como lucro primeira entrada

input group "Sniper Parameters"
input double iSellPrice; // Ponto de venda inicial do gradiente
input double iBuyPrice;  // Ponto de compra inicial do gradiente

input group "Just Parameters"
input double iJustPercentage = 1.0; // Variação percentual do fechamento anterior

input group "Customização"
input ENUM_ON_OFF iTradingView = enabled; //Liga desliga linhas de trade
input ENUM_ON_OFF iTVShowPosistions = enabled; //Liga desliga linhas de posições
input ENUM_ON_OFF iTVShowOrders     = enabled; //Liga desliga linhas de ordens
input ENUM_ON_OFF iTVShowTP = enabled; //Liga desliga linhas de take profit

CTrade trade;
MqlRates rates[];

//int orders_sent;
double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick
long h9k_account;
string h9k_broker;

//BB variables
int hBB; //handler do buffer da banda de bollinger
int hATR; //handler do buffer do ATR
int hIFR; //handler do buffer do RSI/IFR

bool vOrderPlaced = false; //Para registra se a ordem já foi enviada ou não
bool vTPTrigger = false;
bool newBar; //Para saber se estamos em uma nova barra

double vBBHigh[], vBBLow[], vBBMiddle[]; // dynamic arrays for numerical values of Bollinger Bands
double vATR[];
double vIFR[]; //Array para armazenar os valores do IFR

CiMA vMMFast; //Objeto da Média Móvel rápida
CiMA vMMSlow; //Objeto da Média Móvel lenta

double entry_price, stop_loss, vMaxProfit;
datetime entry_time;
bool force_sell, force_buy; // variáveis de controle liga/desliga de compra e venda manual
bool vPauseEA = false;      // variável de controle para pausar/iniciar estratégia
bool vTargetLock = false;
bool vDDTriggerActive = false;
string global_last_entry, global_last_time; //Variáveis que contém os nomes das variáveis globais.
double vAmount;

//variáveis para controle do painel de comentários
string panel_items[] = {"Status:", "Magic:", "Entry Price:", "Result:", "Position ($):", "Total:", "Open pos.:", "Avg. Price:", "Max Loss:", "Daily Result:", 
                        "Week Result:", "Month Result", "ATR:"};
string panel_values[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("inicializando...");
    PrintFormat("Build date: %s", (string)__DATETIME__);
    
    h9k_account = AccountInfoInteger(ACCOUNT_LOGIN);
    h9k_broker = AccountInfoString(ACCOUNT_COMPANY);
    
    PrintFormat("Trading on: %I64d : %s", h9k_account, h9k_broker);
    
    if (!checkParameters()) return INIT_FAILED;
    
    vAmount = iAmount;

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
    ArraySetAsSeries(vBBHigh, true);
    ArraySetAsSeries(vBBLow, true);
    ArraySetAsSeries(vBBMiddle, true);
    ArraySetAsSeries(vATR, true);
    ArraySetAsSeries(vIFR, true);

    ArrayResize(panel_values, ArraySize(panel_items));
    
    vMMFast.Create(_Symbol, iMMTimeFrame, iMMFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
    vMMSlow.Create(_Symbol, iMMTimeFrame, iMMSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);

    hBB = iBands(_Symbol, iBandsTimeFrame, iBandsPeriod, iBandsShift, iBandsDeviation, iBandsAppliedPrice);
    if(hBB < 0) return INIT_FAILED;    
    
    if (iStrategy == bollinger && _Period == iBandsTimeFrame && !ChartIndicatorAdd(0, 0, hBB)) 
        PrintFormat("Falha ao adicionar o indicador Bands %d na janela do gráfico. Código de erro %d", 0, GetLastError());
    
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

    createPanel(250, 360);
    populatePanel(panel_items, panel_values);

    createButtons(12, 278);
    
    if((DailyResult(iMagicNumber) + OpenResult(iMagicNumber)) <= 0.95*iDailyTarget) {
        vTargetLock = false;
    }

    PrintFormat("[%d] Inicializado com sucesso!", iMagicNumber);
    
    EventSetTimer(1);
    
    return(INIT_SUCCEEDED);
}

bool checkParameters(){
    bool cp_ok = true;
    
    if(iMedioParaFrente && iFirstGain < 1.2*iDistance) {
        Alert("Primeiro ganho tem que ser maior que distância para que o médio para frente possa funcionar.");
        cp_ok = false;
    }    
    
    return cp_ok;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{

    /*
    long chart_id = ChartID();
    int  wnd_total = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   
    for(int w=0; w<wnd_total; w++)
     {
      int ind_total=ChartIndicatorsTotal(chart_id, w);
      
      PrintFormat("Chart window %d indicators: ", w);
      
      string ind_names="";
      for(int i=0; i<ind_total; i++)
        {
         ind_names+="  "+ChartIndicatorName(chart_id, w, i)+(i<ind_total-1 ? "\n": "");
        }

      Print(ind_names);
     }*/
     

    if (iStrategy == bollinger && _Period == iBandsTimeFrame) {
        string _iname = StringFormat("Bands(%d)", iBandsPeriod);
        if (!ChartIndicatorDelete(0, 0, _iname)) PrintFormat("Falha ao remover o indicador Bands %d na janela do gráfico. Código de erro %d", 0, GetLastError());
    }
    
    if(hBB != INVALID_HANDLE)
        IndicatorRelease(hBB);
        
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
    
    if (iTradingView) displayTradingInfo();
    
    //Print(OpenResult(iMagicNumber));
}


//+------------------------------------------------------------------+
//| Expert tick function
//+------------------------------------------------------------------+
void OnTick() {
    ulong _ini = GetMicrosecondCount();
    
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
    } else if(vTPTrigger && iMaxPendOrders < iMaxEntries) { //caso estivermos limitando o envio de ordens e tp foi acionado
        closeAllOpenOrders(trade, iMagicNumber);
        vTPTrigger = false;
    }

    panel_values[0] = "running...";
    populatePanel(panel_items, panel_values);
    
    //se for uma estratégia sniper, vamos recolocar as ordens
    if(open_positions + open_orders == 0 && (iStrategy == sniper_buy || iStrategy == sniper_sell)) {
        //em tese, resetando estas variáveis, ele vai abrir para enviar novas ordens
        vTPTrigger = false;
        vOrderPlaced = false;
    }

    if(newBar && open_positions == 0 && iStrategy != sniper_buy && iStrategy != sniper_sell) {
        if(has_open_order(iMagicNumber)) {
            closeAllOpenOrders(trade, iMagicNumber);
            vTPTrigger = false;
            vOrderPlaced = false;
        } else {
            vOrderPlaced = false;
            vTPTrigger = false;
        }
    }

//Coloca o valor dos 3 últimos candles na variável "rates" do tipo array
    int copied  = CopyRates(_Symbol, _Period, 0, 3, rates);
    if(copied <= 0) return; //Caso não consiga pegar as cotações, retorna

    if (CopyBuffer(hBB, 0, 0, 3, vBBMiddle) <=0) return;
    if (CopyBuffer(hBB, 1, 0, 3, vBBHigh) <=0) return;
    if (CopyBuffer(hBB, 2, 0, 3, vBBLow) <=0) return;
    
    //atualizando o valor do ATR
    if (CopyBuffer(hATR, 0, 0, 3, vATR) <= 0) return;
    if (CopyBuffer(hIFR, 0, 0, 3, vIFR) <= 0) return;
    
    /*
    if (vIFR[0] > vIFR[1] && IsBought(iMagicNumber)) {
        if (iAmount + 1 > vAmount) closeAllOpenOrders(trade, iMagicNumber);
        vAmount = iAmount + 1;
    } else if (vIFR[0] <= vIFR[1] && IsBought(iMagicNumber)) {
        if (iAmount + 1 > vAmount) closeAllOpenOrders(trade, iMagicNumber);
        vAmount = iAmount;
    }*/
    
    double close = iClose(_Symbol, PERIOD_D1, 1);
    double today_open = iOpen(_Symbol, PERIOD_D1, 0);
    
    double _bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
    double _ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
    
    vMMFast.Refresh();
    vMMSlow.Refresh();
    
    double vmmf = vMMFast.Main(1);
    double vmms = vMMSlow.Main(1);
        
    bool isAVGBuy  = iStrategy == cruzamento_medias && vMMFast.Main(1) < vMMSlow.Main(1) && vMMFast.Main(0) > vMMSlow.Main(0);
    bool isAVGSell = iStrategy == cruzamento_medias && vMMFast.Main(1) > vMMSlow.Main(1) && vMMFast.Main(0) < vMMSlow.Main(0);

    bool isBuy  = (iStrategy == bollinger && rates[0].close < vBBMiddle[0] && rates[0].close > vBBLow[0])  || iStrategy == sniper_buy
                  || (iStrategy == just && rates[0].close < close) || force_buy || (iStrategy == stIFR && vIFR[0] < iSoldIFR)
                  || (iStrategy == fibo && rates[0].close < today_open) || isAVGBuy;
                  
    bool isSell = (iStrategy == bollinger && rates[0].close > vBBMiddle[0] && rates[0].close < vBBHigh[0]) || iStrategy == sniper_sell
                  || (iStrategy == just && rates[0].close > close) || force_sell || (iStrategy == stIFR && vIFR[0] > iBoughtIFR)
                  || (iStrategy == fibo && rates[0].close > today_open) || isAVGSell;
                  

    if(IsBought(iMagicNumber) && iMedioParaFrente && !iMFTurbo && _bid > (entry_price + iDistance)) {
        entry_price += iDistance;
        
        PrintFormat("[%d] Médio para frente em ação na compra.", iMagicNumber);
        
        closeAllOpenOrders(trade, iMagicNumber);
        
        stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price - iMaxEntries*iDistance, price_step);
        changePositionsSL(trade, iMagicNumber, stop_loss);
    } else if(IsBought(iMagicNumber) && iMedioParaFrente && iMFTurbo && _bid > entry_price && open_positions == 1) {
        entry_price = _bid;
        
        PrintFormat("[%d] MF Turbo em ação na compra.", iMagicNumber);
        
        closeAllOpenOrders(trade, iMagicNumber);
        
        stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price - iMaxEntries*iDistance, price_step);
        changePositionsSL(trade, iMagicNumber, stop_loss);
    } else if(IsSold(iMagicNumber) && iMedioParaFrente && !iMFTurbo &&  _ask < (entry_price - iDistance)) {
        entry_price -= iDistance;
        
        PrintFormat("[%d] Médio para frente em ação na venda.", iMagicNumber);
        
        closeAllOpenOrders(trade, iMagicNumber);        
        
        stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price + iMaxEntries*iDistance, price_step);
        changePositionsSL(trade, iMagicNumber, stop_loss);
    } else if(IsSold(iMagicNumber) && iMedioParaFrente && iMFTurbo && _ask < entry_price && open_positions == 1) {
        entry_price = _ask;
        
        PrintFormat("[%d] MF Turbo em ação na venda.", iMagicNumber);
        
        closeAllOpenOrders(trade, iMagicNumber);        
        
        stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price + iMaxEntries*iDistance, price_step);
        changePositionsSL(trade, iMagicNumber, stop_loss);
    }
    

    open_positions = HasPosition(iMagicNumber);
    open_orders    = OpenOrdersCount(iMagicNumber);
    
    //Gerenciamento das posições e ordens, se faltar alguma ele vai tentar consertar
    if(open_positions > 0 && open_positions + open_orders != iMaxEntries && open_orders < iMaxPendOrders) {
        PrintFormat("[%I64d] Ajustando a grade: %d + %d = %d (%d)", iMagicNumber, open_positions, open_orders, open_positions+open_orders, iMaxEntries);
        
        int cur_open_orders = open_orders;

        for (int i = open_positions; i < iMaxEntries; i++) {
            
            double order_price = 0;
            bool order_sent = false;
            bool bought = IsBought(iMagicNumber);
            bool sold = IsSold(iMagicNumber);

            if (bought) {
                order_price = entry_price - (i * iDistance);
            } else if (sold) {
                order_price = entry_price + (i * iDistance);
            }

            if(!has_order_at(order_price, iMagicNumber, 0)) {                
                if (bought && rates[0].close > order_price) {
                    stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price - iMaxEntries*iDistance, price_step);
                    trade.BuyLimit(iAmount, order_price, _Symbol, stop_loss, order_price + iGainDistance, ORDER_TIME_DAY, 0, "Reposição ordem de compra "+(string)(i+1) +" limite.");
                    order_sent = true;
                } else if(sold && rates[0].close < order_price) {
                    stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price + iMaxEntries*iDistance, price_step);                    
                    trade.SellLimit(iAmount, order_price, _Symbol, stop_loss, order_price - iGainDistance, ORDER_TIME_DAY, 0, "Reposição ordem de venda "+(string)(i+1) +" limite.");
                    order_sent = true;
                }
                
                if(order_sent && !orderRejected(trade.ResultRetcode())) {
                    while(!has_order_at(order_price, iMagicNumber, 0) && !IsStopped()) {
                        Print("Waiting for the order to be placed");
                        Sleep(500);
                        //por algumas circunstâncias ele pode cair aqui e ficar em um loop infinito, vamos sair se não tiver posição
                        if(HasPosition(iMagicNumber) == 0)
                            break;
                    }            
                    cur_open_orders++;
                }
                
                if (cur_open_orders >= iMaxPendOrders)
                    break;
            }
        }
    }

//Montagem inicial da grade na ponta comprada
    if (isBuy && HasPosition(iMagicNumber) == 0 && !vOrderPlaced) {

        if (iStrategy == bollinger) {
            entry_price = roundPriceH9K(vBBLow[0], price_step);
        } else if (iStrategy == fibo) {
            entry_price = fibo_entry_price("buy");           
        } else if(iStrategy == sniper_buy && rates[0].close > iBuyPrice) {
            entry_price = iBuyPrice;
        } else if (iStrategy == just) {
            entry_price = roundPriceH9K(close * (1 - (iJustPercentage/100)), price_step);
        } else if (iStrategy == manual || iStrategy == stIFR || iStrategy == cruzamento_medias) {
            double _tp = rates[0].close + iFirstGain;
            stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(rates[0].close - iMaxEntries*iDistance, price_step);
            
            trade.Buy(iAmount, _Symbol, 0, stop_loss, _tp, "Enviando ordem de compra a mercado");
            
            if(!orderRejected(trade.ResultRetcode())) {
                while(!HasPosition(iMagicNumber) && !IsStopped()) { //se der algun status bizarro pode entrar em loop.
                    Print("waiting for order to be filled...");
                    Sleep(500);
                }
                if(HasAndSelectSinglePosition(iMagicNumber)) {//garantir posição única
                    entry_time = TimeCurrent();
                    entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                    _tp = entry_price + iFirstGain;
                    stop_loss = iIgnoreGridLoss ? 0 : entry_price - (iMaxEntries * iDistance);
                    changePositions(trade, iMagicNumber, stop_loss, _tp);                    
                } else {
                    Print("Multiple positions found, using the lower one, this can be dangerous");
                    entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                }

            }
            
            entry_time = TimeCurrent();
            vOrderPlaced = true;
            force_buy = false; //não permitir reentrada automática
        
            return;
        } else {
            return;
        }

        stop_loss = roundPriceH9K(entry_price - iMaxEntries*iDistance, price_step);

        for (int i = 0; i < iMaxPendOrders; i++) {

            double order_price = entry_price - (i * iDistance);

            if (i == 0) {
                trade.BuyLimit(iAmount, order_price, _Symbol, stop_loss, order_price + iFirstGain, ORDER_TIME_DAY, 0, "Ordem de compra "+(string)(i+1) +" limite.");
            } else {
                trade.BuyLimit(iAmount, order_price, _Symbol, stop_loss, order_price + iGainDistance, ORDER_TIME_DAY, 0, "Ordem de compra "+(string)(i+1) +" limite.");                
            }
        }

        entry_time = TimeCurrent();
        vOrderPlaced = true;
        force_buy = false; //não permitir reentrada automática

    } else if (isSell && HasPosition(iMagicNumber) == 0 && !vOrderPlaced) { //Montagem inicial da grade na ponta vendida

        if (iStrategy == bollinger)  {
            entry_price = roundPriceH9K(vBBHigh[0], price_step);
        } else if (iStrategy == fibo) {
            entry_price = fibo_entry_price("sell"); 
        } else if(iStrategy == sniper_sell && rates[0].close < iSellPrice) {
            entry_price = iSellPrice;
        } else if (iStrategy == just) {
            entry_price = roundPriceH9K(close * (1 + (iJustPercentage/100)), price_step);
        } else if (iStrategy == manual || iStrategy == stIFR || iStrategy == cruzamento_medias) {
            double _tp = rates[0].close - iFirstGain;
            stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(rates[0].close + iMaxEntries*iDistance, price_step);
            
            trade.Sell(iAmount, _Symbol, 0, stop_loss, _tp, "Enviando ordem de venda a mercado");
            
            if(!orderRejected(trade.ResultRetcode())) {
                while(!HasPosition(iMagicNumber) && !IsStopped()) { //se der algun status bizarro pode entrar em loop.
                    Print("waiting for order to be filled...");
                    Sleep(500);
                }
                if(HasAndSelectSinglePosition(iMagicNumber)) {//garantir posição única
                    entry_time = TimeCurrent();
                    entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                    _tp = entry_price - iFirstGain;
                    stop_loss = iIgnoreGridLoss ? 0 : entry_price + (iMaxEntries * iDistance);
                    changePositions(trade, iMagicNumber, stop_loss, _tp);
                } else {
                    Print("Multiple positions found, using the lower one, this can be dangerous");
                    entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                }

            }
            
            entry_time = TimeCurrent();
            vOrderPlaced = true;
            force_sell = false; //não permitir reentrada automática
            
            return;
        } else {
            return;
        }

        stop_loss = iIgnoreGridLoss ? 0 : roundPriceH9K(entry_price + iMaxEntries*iDistance, price_step);

        for(int i = 0; i < iMaxPendOrders; i++) {
            double order_price = entry_price + (i * iDistance);
            if (i == 0) {
                trade.SellLimit(iAmount, order_price, _Symbol, stop_loss, order_price - iFirstGain, ORDER_TIME_DAY, 0, "Ordem venda "+(string)(i+1) +" limite.");
            } else {
                trade.SellLimit(iAmount, order_price, _Symbol, stop_loss, order_price - iGainDistance, ORDER_TIME_DAY, 0, "Ordem venda "+(string)(i+1) +" limite.");
            }

        }

        entry_time = TimeCurrent();
        vOrderPlaced = true;
        force_sell = false; //não permitir reentrada automática

    }
    
    ulong _fim = GetMicrosecondCount();    
    //Print("Tempo gasto OnTick: ", _fim - _ini);

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
    } else if(sparam == "myButton_Buy" && iStrategy == manual && lparam > 0) {
        if (!vPauseEA && !force_sell && !force_buy) {
            force_buy = true;
            force_sell = false;
            Print("Buying right now!");
        }
    } else if(sparam == "myButton_Sell" && iStrategy == manual && lparam > 0) {
        if (!vPauseEA && !force_sell && !force_buy) {
            force_sell = true;
            force_buy = false;
            Print("Selling right now!");
        }
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

    if (iStrategy == manual) {
        ObjectCreate(0, "myButton_Buy",OBJ_BUTTON,0,0,0);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_XDISTANCE, l_x);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_YDISTANCE, l_y + 55);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_XSIZE,115);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_YSIZE,50);
        ObjectSetString(0, "myButton_Buy",OBJPROP_TEXT,"Buy");
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_COLOR, C'255,240,245');
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_BGCOLOR, C'38,166,154');
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_BORDER_COLOR, C'38,166,154');
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_BORDER_TYPE,BORDER_FLAT);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_BACK, false);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_STATE, false);
        ObjectSetInteger(0, "myButton_Buy",OBJPROP_FONTSIZE, 12);

        ObjectCreate(0, "myButton_Sell",OBJ_BUTTON,0,0,0);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_XDISTANCE, l_x + 120);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_YDISTANCE, l_y + 55);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_XSIZE, 115);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_YSIZE, 50);
        ObjectSetString(0, "myButton_Sell",OBJPROP_TEXT,"Sell");
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_COLOR, C'255,240,245');
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_BGCOLOR, C'239,83,80');
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_BORDER_COLOR, C'239,83,80');
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_BORDER_TYPE,BORDER_FLAT);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_BACK, false);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_STATE, false);
        ObjectSetInteger(0, "myButton_Sell",OBJPROP_FONTSIZE, 12);
    }

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

double fibo_entry_price(string _lado) {
    datetime currentTime = TimeCurrent();            
    datetime startOfDay = currentTime - (currentTime % 86400);

    int firstBarIndex = iBarShift(_Symbol, iFiboTF, startOfDay);
    
    // Obter informações da primeira barra
    double high = iHigh(_Symbol, iFiboTF, firstBarIndex);
    double low = iLow(_Symbol, iFiboTF, firstBarIndex);            
    double amplitude = high - low;
    
    if(_lado == "buy") {
        return roundPriceH9K(low - iFibo*amplitude, price_step);
    } else {
        return roundPriceH9K(high + iFibo*amplitude, price_step);
    }
        
}


void displayTradingInfo() {
    int open_positions = HasPosition(iMagicNumber);
    int open_orders    = OpenOrdersCount(iMagicNumber);
    
    ObjectsDeleteAll(0, "H9k_GL_TV_", 0, -1);
    
    /*    
    int _obj_total = ObjectsTotal(0, 0, -1);
    
    
    for(int i = 0; i < _obj_total; i++) {
        string objName = ObjectName(0, i, 0, -1); // Obtém o nome do objeto na posição i
        //Print("Objeto encontrado: ", objName);
        if(StringSubstr(objName, 0, StringLen("xH9k_")) == "xH9k_") {
            Print("Objeto encontrado: ", objName);
        }
    }

    */    

    if (iTVShowOrders) {        
        for (int i = 0; i < open_orders; i++) {
            COrderInfo _ord;
            _ord.SelectByIndex(i);
            
            if(_ord.Magic() == iMagicNumber) {
                string _name = StringFormat("H9k_GL_TV_O_%I64d", _ord.Ticket());
                SetHL(_name, _ord.PriceOpen(), clrBlueViolet);
            }    
           
        }
    }
    
    if (iTVShowPosistions) {
        for (int i = 0; i < open_positions; i++) {
            CPositionInfo _pos;
            _pos.SelectByIndex(i);
            
            if(_pos.Magic() == iMagicNumber) {
                string _name = StringFormat("H9k_GL_TV_P_%I64d", _pos.Ticket());
                SetHL(_name, _pos.PriceOpen(), clrYellow);
                _name = StringFormat("H9k_GL_TV_P_SL_%I64d", _pos.Ticket());
                SetHL(_name, _pos.StopLoss(), clrMaroon, STYLE_DASHDOT);
                if (iTVShowTP) {
                    _name = StringFormat("H9k_GL_TV_P_TP_%I64d", _pos.Ticket());
                    SetHL(_name, _pos.TakeProfit(), clrAquamarine, STYLE_DASH);
                }
            }    
           
        }
    }
    
    ChartRedraw(0);
    
}
