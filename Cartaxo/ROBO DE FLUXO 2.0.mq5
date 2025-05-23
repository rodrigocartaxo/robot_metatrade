//+------------------------------------------------------------------+
//|                                    WAGNER BOT                    |
//+------------------------------------------------------------------+
#property copyright "JMTRADER BOT"
#property link      " "
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- input parameters
input group "Account Settings"
input bool UseHedging = false; // True = Hedge, False = Netting

input group "Daytrade Window"
input string iHoraIni = "09:15:00"; //Hora inicio
input string iHoraFim = "18:30:00"; //Hora fim
input string iBlockNewPositions = "17:00:00"; //Depois deste horário não vai mais abrir posição
input long   iMagicNumber       = 01;

input group "Basic Settings"
input double iAmount   = 1;   //Quantidade de Contratos
input double iStopLoss = 100; //Stop Loss (pontos)
input double iTakeProfit = 200; //Take Profit (pontos)
input double iTrailingStop = 50; //Trailing Stop (pontos)

input group "Order Flow Parameters"
input int Volume_Threshold = 300;       //Limite de volume para considerar desequilíbrio (em lotes)
input double Imbalance_Percentage = 60; //Percentual de desequilíbrio para ativar entrada (%)
input int Time_Window = 10;             //Janela de tempo para monitoramento (segundos)
input int MA_Period = 10;               //Período da Média Móvel

input group "Daily Limits (in BRL)"
input double DailyProfitTarget = 150.0; // Meta de Ganho Diário (R$)
input double DailyStopLoss = -50.0;     // Stop Loss Diário (R$)

// Data de expiração fixa
#define EXPIRATION_DATE "2500.04.10 00:00:00"

// Cores do painel
#define CLR_BG          clrBlack
#define CLR_BORDER      C'70,70,70'
#define CLR_TEXT_GREEN  clrLime
#define CLR_TEXT_RED    clrRed
#define CLR_TEXT_WHITE  clrWhite
#define CLR_TITLE_BG    C'10,10,10'
#define CLR_PROGRESS_BG C'30,30,30'
#define CLR_PROGRESS_BUY CLR_TEXT_GREEN
#define CLR_PROGRESS_SELL CLR_TEXT_RED

// Posição e tamanho do painel
#define PANEL_X         20
#define PANEL_Y         20
#define PANEL_WIDTH     260
#define PANEL_HEIGHT    340
#define LINE_HEIGHT     22
#define BAR_HEIGHT      14

CTrade trade;
MqlRates rates[];

//Order flow variables
ulong buyVolume;
ulong sellVolume;
ulong totalVolume;
datetime lastUpdateTime;
double lastPrice = 0;
double movingAverage = 0.0;
int maHandle = INVALID_HANDLE;
double dailyProfitLoss = 0.0;

double price_step;
bool vOrderPlaced = false;
double entry_price;
bool isBuyDirection = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    datetime expiration = StringToTime(EXPIRATION_DATE);
    if(TimeCurrent() >= expiration) {
        Print("O robô expirou em ", EXPIRATION_DATE, ". Entre em contato com o suporte.");
        return INIT_FAILED;
    }

    price_step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    int margin_mode = (int)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
    if(UseHedging && margin_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
        Print("Configurado para HEDGE mas a conta não suporta hedging!");
        return INIT_FAILED;
    }
    if(!UseHedging && margin_mode != ACCOUNT_MARGIN_MODE_RETAIL_NETTING) {
        Print("Configurado para NETTING mas a conta não suporta netting!");
        return INIT_FAILED;
    }

    if(iStopLoss <= 0 || iTakeProfit <= 0 || iTrailingStop <= 0) {
        Print("SL, TP ou Trailing Stop inválidos! Devem ser maiores que zero.");
        return INIT_PARAMETERS_INCORRECT;
    }

    ArraySetAsSeries(rates, true);
    
    maHandle = iMA(_Symbol, PERIOD_CURRENT, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE) {
        Print("Erro ao criar handle da Média Móvel: ", GetLastError());
        return INIT_FAILED;
    }

    buyVolume = 0;
    sellVolume = 0;
    totalVolume = 0;
    lastUpdateTime = TimeCurrent();
    lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);

    trade.SetExpertMagicNumber(iMagicNumber);
    
    CreateDashboard();
    CalculateDailyProfitLoss();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(maHandle != INVALID_HANDLE)
        IndicatorRelease(maHandle);
    
    DeleteDashboard();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime expiration = StringToTime(EXPIRATION_DATE);
    if(TimeCurrent() >= expiration) {
        Print("O robô expirou em ", EXPIRATION_DATE, ". Encerrando operações.");
        CloseAllPositions();
        Comment("Robô expirado em " + EXPIRATION_DATE);
        return;
    }

    datetime currentTime = TimeCurrent();
    datetime startTime = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + iHoraIni);
    datetime endTime = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + iHoraFim);
    datetime blockTime = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + iBlockNewPositions);

    CalculateDailyProfitLoss();
    
    if(CheckDailyLimits()) {
        Comment("Limite diário atingido");
        CloseAllPositions();
        UpdateDashboard();
        return;
    }

    if(currentTime < startTime || currentTime > endTime) {
        Comment("Not allowed by hour");
        if(UseHedging)
            CloseAllPositions();
        else
            trade.PositionClose(_Symbol);
        UpdateDashboard();
        return;
    }

    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates);
    if(copied <= 0) return;

    UpdateMovingAverage();
    UpdateVolumes();

    int open_positions = GetOpenPositionsCount();

    if(open_positions == 0 && vOrderPlaced) {
        vOrderPlaced = false;
    }

    if(open_positions > 0) {
        ManageTrailingStop();
    }

    if(currentTime - lastUpdateTime >= Time_Window && currentTime < blockTime) {
        AnalyzeVolumeImbalance();
        buyVolume = 0;
        sellVolume = 0;
        totalVolume = 0;
        lastUpdateTime = currentTime;
    }
    
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Get open positions count function                                |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
    if(!UseHedging)
        return PositionsTotal();
        
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == iMagicNumber &&
           PositionGetString(POSITION_SYMBOL) == _Symbol)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Close all positions (for hedging mode)                           |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == iMagicNumber &&
           PositionGetString(POSITION_SYMBOL) == _Symbol) {
            trade.PositionClose(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Update volumes function                                          |
//+------------------------------------------------------------------+
void UpdateVolumes()
{
    MqlTick lastTick;
    if(SymbolInfoTick(_Symbol, lastTick)) {
        double currentPrice = lastTick.last;
        
        if(currentPrice > 0 && lastPrice > 0) {
            ulong tickVolume = lastTick.volume;
            
            if(currentPrice > lastPrice)
                buyVolume += tickVolume;
            else if(currentPrice < lastPrice)
                sellVolume += tickVolume;
            else {
                buyVolume += tickVolume / 2;
                sellVolume += tickVolume / 2;
            }
            
            totalVolume = buyVolume + sellVolume;
        }
        
        lastPrice = currentPrice;
    }
}

//+------------------------------------------------------------------+
//| Update moving average function                                   |
//+------------------------------------------------------------------+
void UpdateMovingAverage()
{
    double maBuffer[];
    ArraySetAsSeries(maBuffer, true);
    
    if(CopyBuffer(maHandle, 0, 0, 1, maBuffer) <= 0) {
        Print("Erro ao copiar valores da Média Móvel: ", GetLastError());
        return;
    }
    
    movingAverage = maBuffer[0];
}

//+------------------------------------------------------------------+
//| Analyze volume imbalance function                                |
//+------------------------------------------------------------------+
void AnalyzeVolumeImbalance()
{
    if(totalVolume >= Volume_Threshold) {
        double buyPercent = (double)buyVolume / totalVolume * 100;
        double sellPercent = (double)sellVolume / totalVolume * 100;
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
        
        if(buyPercent >= Imbalance_Percentage && currentPrice > movingAverage && GetOpenPositionsCount() == 0 && !vOrderPlaced) {
            Print("Desequilíbrio de compra detectado!");
            entry_price = NormalizeDouble(currentPrice, Digits());
            double sl = NormalizeDouble(entry_price - iStopLoss * price_step, Digits());
            double tp = NormalizeDouble(entry_price + iTakeProfit * price_step, Digits());
            
            if(trade.Buy(iAmount, _Symbol, entry_price, sl, tp, "Ordem de compra")) {
                vOrderPlaced = true;
                isBuyDirection = true;
            } else {
                Print("Erro ao colocar ordem de compra: ", GetLastError());
            }
        }
        else if(sellPercent >= Imbalance_Percentage && currentPrice < movingAverage && GetOpenPositionsCount() == 0 && !vOrderPlaced) {
            Print("Desequilíbrio de venda detectado!");
            entry_price = NormalizeDouble(currentPrice, Digits());
            double sl = NormalizeDouble(entry_price + iStopLoss * price_step, Digits());
            double tp = NormalizeDouble(entry_price - iTakeProfit * price_step, Digits());
            
            if(trade.Sell(iAmount, _Symbol, entry_price, sl, tp, "Ordem de venda")) {
                vOrderPlaced = true;
                isBuyDirection = false;
            } else {
                Print("Erro ao colocar ordem de venda: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Manage trailing stop function                                    |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == iMagicNumber &&
           PositionGetString(POSITION_SYMBOL) == _Symbol) {
           
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                double newSL = NormalizeDouble(currentPrice - iTrailingStop * price_step, Digits());
                if(newSL > currentSL && currentPrice > openPrice + iTrailingStop * price_step) {
                    if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP))) {
                        Print("Trailing Stop ajustado para compra: ", newSL);
                    }
                }
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                double newSL = NormalizeDouble(currentPrice + iTrailingStop * price_step, Digits());
                if((newSL < currentSL || currentSL == 0) && currentPrice < openPrice - iTrailingStop * price_step) {
                    if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP))) {
                        Print("Trailing Stop ajustado para venda: ", newSL);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calcula o resultado líquido do dia                               |
//+------------------------------------------------------------------+
void CalculateDailyProfitLoss()
{
    dailyProfitLoss = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && 
           PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == iMagicNumber)
            dailyProfitLoss += PositionGetDouble(POSITION_PROFIT);
    }
    
    datetime today_start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00");
    if(!HistorySelect(today_start, TimeCurrent())) {
        Print("Erro ao selecionar histórico de negociações!");
        return;
    }
    
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(dealTicket, DEAL_TIME) >= today_start && 
           HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol &&
           HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == iMagicNumber) {
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                dailyProfitLoss += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        }
    }
}

//+------------------------------------------------------------------+
//| Verifica se os limites diários foram atingidos                   |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
    if(DailyProfitTarget > 0 && dailyProfitLoss >= DailyProfitTarget) {
        Print("Meta de ganho diário atingida: R$", DoubleToString(dailyProfitLoss, 2));
        return true;
    }
    
    if(DailyStopLoss < 0 && dailyProfitLoss <= DailyStopLoss) {
        Print("Stop loss diário atingido: R$", DoubleToString(dailyProfitLoss, 2));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Função para criar o painel dinâmico                              |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    ObjectCreate(0, "Dashboard_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_XDISTANCE, PANEL_X);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_YDISTANCE, PANEL_Y);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_XSIZE, PANEL_WIDTH);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_YSIZE, PANEL_HEIGHT);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_COLOR, CLR_BORDER);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_BGCOLOR, CLR_BG);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_BACK, false);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_ZORDER, 0);
    
    ObjectCreate(0, "Dashboard_Title_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_XDISTANCE, PANEL_X);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_YDISTANCE, PANEL_Y);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_XSIZE, PANEL_WIDTH);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_YSIZE, 30);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_COLOR, CLR_BORDER);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_BGCOLOR, CLR_TITLE_BG);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "Dashboard_Title_BG", OBJPROP_ZORDER, 1);
    
    CreateHorizontalLine("Separator1", PANEL_Y + 30, PANEL_WIDTH);
    CreateHorizontalLine("Separator2", PANEL_Y + 160, PANEL_WIDTH);
    
    CreateLabel("Title", "DADOS DO FLUXO", PANEL_X + 5, PANEL_Y + 5, CLR_TEXT_WHITE, 12, true);
    CreateLabel("BuyVolText", "Compra:", PANEL_X + 10, PANEL_Y + 40, CLR_TEXT_WHITE, 9);
    CreateLabel("BuyVol", "0", PANEL_X + 90, PANEL_Y + 40, CLR_TEXT_GREEN, 9);
    CreateLabel("SellVolText", "Venda:", PANEL_X + 10, PANEL_Y + 60, CLR_TEXT_WHITE, 9);
    CreateLabel("SellVol", "0", PANEL_X + 90, PANEL_Y + 60, CLR_TEXT_RED, 9);
    CreateLabel("TotalVolText", "Total:", PANEL_X + 10, PANEL_Y + 80, CLR_TEXT_WHITE, 9);
    CreateLabel("TotalVol", "0", PANEL_X + 90, PANEL_Y + 80, CLR_TEXT_WHITE, 9);
    CreateLabel("BuyPercText", "Compra %:", PANEL_X + 140, PANEL_Y + 40, CLR_TEXT_WHITE, 9);
    CreateLabel("BuyPerc", "0.0%", PANEL_X + 200, PANEL_Y + 40, CLR_TEXT_GREEN, 9);
    CreateLabel("SellPercText", "Venda %:", PANEL_X + 140, PANEL_Y + 60, CLR_TEXT_WHITE, 9);
    CreateLabel("SellPerc", "0.0%", PANEL_X + 200, PANEL_Y + 60, CLR_TEXT_RED, 9);
    CreateLabel("MAText", "Média:", PANEL_X + 140, PANEL_Y + 80, CLR_TEXT_WHITE, 9);
    CreateLabel("MAValue", "0.00", PANEL_X + 200, PANEL_Y + 80, CLR_TEXT_WHITE, 9);
    CreateLabel("StatusText", "Status:", PANEL_X + 10, PANEL_Y + 100, CLR_TEXT_WHITE, 9);
    CreateLabel("Status", "Aguardando", PANEL_X + 90, PANEL_Y + 100, CLR_TEXT_WHITE, 9);
    CreateLabel("SignalText", "Sinal:", PANEL_X + 10, PANEL_Y + 120, CLR_TEXT_WHITE, 9);
    CreateLabel("Signal", "Nenhum", PANEL_X + 90, PANEL_Y + 120, CLR_TEXT_WHITE, 9);
    
    CreateLabel("FluxoText", "Fluxo:", PANEL_X + 10, PANEL_Y + 140, CLR_TEXT_WHITE, 9);
    
    ObjectCreate(0, "FluxoBarBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_XDISTANCE, PANEL_X + 90);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_YDISTANCE, PANEL_Y + 140);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_YSIZE, BAR_HEIGHT);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_COLOR, CLR_BORDER);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_BGCOLOR, CLR_PROGRESS_BG);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "FluxoBarBG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    ObjectCreate(0, "FluxoBarBuy", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_XDISTANCE, PANEL_X + 90);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_YDISTANCE, PANEL_Y + 140);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_XSIZE, 0);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_YSIZE, BAR_HEIGHT);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_COLOR, CLR_BORDER);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_BGCOLOR, CLR_PROGRESS_BUY);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    ObjectCreate(0, "FluxoBarSell", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_XDISTANCE, PANEL_X + 90);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_YDISTANCE, PANEL_Y + 140);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_XSIZE, 0);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_YSIZE, BAR_HEIGHT);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_COLOR, CLR_BORDER);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_BGCOLOR, CLR_PROGRESS_SELL);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    CreateLabel("OperationTitle", "DADOS DA OPERAÇÃO", PANEL_X + 5, PANEL_Y + 170, CLR_TEXT_WHITE, 10, true);
    CreateLabel("PositionsText", "Posições:", PANEL_X + 10, PANEL_Y + 195, CLR_TEXT_WHITE, 9);
    CreateLabel("Positions", "0", PANEL_X + 90, PANEL_Y + 195, CLR_TEXT_WHITE, 9);
    CreateLabel("OrdersText", "Ordens:", PANEL_X + 10, PANEL_Y + 215, CLR_TEXT_WHITE, 9);
    CreateLabel("Orders", "0", PANEL_X + 90, PANEL_Y + 215, CLR_TEXT_WHITE, 9);
    CreateLabel("DailyPLText", "Resultado Líquido:", PANEL_X + 10, PANEL_Y + 235, CLR_TEXT_WHITE, 9);
    CreateLabel("DailyPL", "R$ 0.00", PANEL_X + 110, PANEL_Y + 235, CLR_TEXT_WHITE, 10, true);
    CreateLabel("TimeText", "Próx. Análise:", PANEL_X + 10, PANEL_Y + 255, CLR_TEXT_WHITE, 9);
    CreateLabel("Time", "00:00", PANEL_X + 90, PANEL_Y + 255, CLR_TEXT_WHITE, 9);
    CreateLabel("ProfitTargetText", "Meta Ganho:", PANEL_X + 10, PANEL_Y + 275, CLR_TEXT_WHITE, 9);
    CreateLabel("ProfitTarget", "R$ " + DoubleToString(DailyProfitTarget, 2), PANEL_X + 110, PANEL_Y + 275, CLR_TEXT_GREEN, 9);
    CreateLabel("StopLossText", "Stop Loss:", PANEL_X + 10, PANEL_Y + 295, CLR_TEXT_WHITE, 9);
    CreateLabel("StopLoss", "R$ " + DoubleToString(DailyStopLoss, 2), PANEL_X + 110, PANEL_Y + 295, CLR_TEXT_RED, 9);
    CreateLabel("Version", "v2.00", PANEL_X + PANEL_WIDTH - 30, PANEL_Y + PANEL_HEIGHT - 20, CLR_TEXT_WHITE, 8);
}

//+------------------------------------------------------------------+
//| Função auxiliar para criar labels                                |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize = 10, bool bold = false)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Função para criar linha horizontal                               |
//+------------------------------------------------------------------+
void CreateHorizontalLine(string name, int y, int width)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PANEL_X);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
    ObjectSetInteger(0, name, OBJPROP_COLOR, CLR_BORDER);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, CLR_BORDER);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
}

//+------------------------------------------------------------------+
//| Função para atualizar o painel dinâmico                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    double buyPercent = (totalVolume > 0) ? (double)buyVolume / totalVolume * 100 : 0;
    double sellPercent = (totalVolume > 0) ? (double)sellVolume / totalVolume * 100 : 0;
    
    ObjectSetString(0, "BuyVol", OBJPROP_TEXT, IntegerToString(buyVolume));
    ObjectSetString(0, "SellVol", OBJPROP_TEXT, IntegerToString(sellVolume));
    ObjectSetString(0, "TotalVol", OBJPROP_TEXT, IntegerToString(totalVolume));
    ObjectSetString(0, "BuyPerc", OBJPROP_TEXT, DoubleToString(buyPercent, 1) + "%");
    ObjectSetString(0, "SellPerc", OBJPROP_TEXT, DoubleToString(sellPercent, 1) + "%");
    ObjectSetString(0, "MAValue", OBJPROP_TEXT, DoubleToString(movingAverage, 2));
    
    int totalBarWidth = 150;
    int buyBarWidth = (totalVolume > 0) ? (int)((buyPercent / 100) * totalBarWidth) : 0;
    int sellBarWidth = (totalVolume > 0) ? (int)((sellPercent / 100) * totalBarWidth) : 0;
    
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_XDISTANCE, PANEL_X + 90);
    ObjectSetInteger(0, "FluxoBarBuy", OBJPROP_XSIZE, buyBarWidth);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_XDISTANCE, PANEL_X + 90 + buyBarWidth);
    ObjectSetInteger(0, "FluxoBarSell", OBJPROP_XSIZE, sellBarWidth);
    
    string status = "Aguardando";
    color statusColor = CLR_TEXT_WHITE;
    string signal = "Nenhum";
    color signalColor = CLR_TEXT_WHITE;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
    datetime currentTime = TimeCurrent();
    datetime startTime = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + iHoraIni);
    datetime endTime = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + iHoraFim);
    
    if(currentTime < startTime || currentTime > endTime) {
        status = "Fora do Horário";
        statusColor = CLR_TEXT_RED;
    }
    else if(CheckDailyLimits()) {
        status = "Limite Atingido";
        statusColor = CLR_TEXT_RED;
    }
    else if(buyPercent >= Imbalance_Percentage && currentPrice > movingAverage) {
        status = "Ativado";
        statusColor = CLR_TEXT_GREEN;
        signal = "COMPRA";
        signalColor = CLR_TEXT_GREEN;
    }
    else if(sellPercent >= Imbalance_Percentage && currentPrice < movingAverage) {
        status = "Ativado";
        statusColor = CLR_TEXT_RED;
        signal = "VENDA";
        signalColor = CLR_TEXT_RED;
    }
    
    ObjectSetString(0, "Status", OBJPROP_TEXT, status);
    ObjectSetInteger(0, "Status", OBJPROP_COLOR, statusColor);
    ObjectSetString(0, "Signal", OBJPROP_TEXT, signal);
    ObjectSetInteger(0, "Signal", OBJPROP_COLOR, signalColor);
    
    int positionsCount = GetOpenPositionsCount();
    int ordersCount = OrdersTotal();
    
    color dailyPLColor = (dailyProfitLoss >= 0) ? CLR_TEXT_GREEN : CLR_TEXT_RED;
    string dailyPLStr = "R$ " + DoubleToString(dailyProfitLoss, 2);
    
    ObjectSetString(0, "Positions", OBJPROP_TEXT, IntegerToString(positionsCount));
    ObjectSetString(0, "Orders", OBJPROP_TEXT, IntegerToString(ordersCount));
    ObjectSetString(0, "DailyPL", OBJPROP_TEXT, dailyPLStr);
    ObjectSetInteger(0, "DailyPL", OBJPROP_COLOR, dailyPLColor);
    
    int secondsRemaining = (int)(Time_Window - (TimeCurrent() - lastUpdateTime));
    string timeStr = (secondsRemaining > 0) ? IntegerToString(secondsRemaining) + "s" : "Agora";
    ObjectSetString(0, "Time", OBJPROP_TEXT, timeStr);
}

//+------------------------------------------------------------------+
//| Função para deletar o painel                                     |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
    ObjectDelete(0, "Dashboard_BG");
    ObjectDelete(0, "Dashboard_Title_BG");
    ObjectDelete(0, "Separator1");
    ObjectDelete(0, "Separator2");
    ObjectDelete(0, "Title");
    ObjectDelete(0, "BuyVolText");
    ObjectDelete(0, "BuyVol");
    ObjectDelete(0, "SellVolText");
    ObjectDelete(0, "SellVol");
    ObjectDelete(0, "TotalVolText");
    ObjectDelete(0, "TotalVol");
    ObjectDelete(0, "BuyPercText");
    ObjectDelete(0, "BuyPerc");
    ObjectDelete(0, "SellPercText");
    ObjectDelete(0, "SellPerc");
    ObjectDelete(0, "MAText");
    ObjectDelete(0, "MAValue");
    ObjectDelete(0, "StatusText");
    ObjectDelete(0, "Status");
    ObjectDelete(0, "SignalText");
    ObjectDelete(0, "Signal");
    ObjectDelete(0, "FluxoText");
    ObjectDelete(0, "FluxoBarBG");
    ObjectDelete(0, "FluxoBarBuy");
    ObjectDelete(0, "FluxoBarSell");
    ObjectDelete(0, "OperationTitle");
    ObjectDelete(0, "PositionsText");
    ObjectDelete(0, "Positions");
    ObjectDelete(0, "OrdersText");
    ObjectDelete(0, "Orders");
    ObjectDelete(0, "DailyPLText");
    ObjectDelete(0, "DailyPL");
    ObjectDelete(0, "TimeText");
    ObjectDelete(0, "Time");
    ObjectDelete(0, "ProfitTargetText");
    ObjectDelete(0, "ProfitTarget");
    ObjectDelete(0, "StopLossText");
    ObjectDelete(0, "StopLoss");
    ObjectDelete(0, "Version");
}