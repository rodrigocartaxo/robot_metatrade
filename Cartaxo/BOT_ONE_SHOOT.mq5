//+------------------------------------------------------------------+
//|                              H9k_maximas_e_minimas_multicurrency.mq5
//|                                              H9k Trading Systems
//|                               https://www.youtube.com/@h9ktrades
//+------------------------------------------------------------------+

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>

#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>


// Structure to hold currency-specific data
struct CurrencyData {
    string symbol;
    double high;
    double low;
    double target;
    bool allowTrade;
    bool setReversionOrders;
    MqlRates rates[];
};

input group "==== Params ====";
input string iTimeStart       = "09:05:00"; //Horário de referência
input double iAmount          = 2;          //Quantidade de lotes
input bool   iReversion      = true;       //Usar reversão?
input bool   iUseFixedTarget = false;      //User take fixo?
input double iFixedTarget    = 300;        //Distância em pontos para o take


datetime vStartTime;
CurrencyData symbolsData[];  // Changed variable name from currencies to symbolsData
CTrade trade;
MyPainel painel;
TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Initialize currency pairs
    string symbolsArray[];
    int totalPairs = StringSplit(currencies, ',', symbolsArray);
    
    if(totalPairs == 0) {
        Print("Erro: Nenhum símbolo configurado");
        return INIT_FAILED;
    }
    
    ArrayResize(symbolsData, totalPairs);  // Updated array name
    
    // Initialize data for each currency pair
    for(int i = 0; i < totalPairs; i++) {
        symbolsData[i].symbol = symbolsArray[i];  // Updated array name
        symbolsData[i].allowTrade = true;         // Updated array name
        symbolsData[i].setReversionOrders = false;  // Updated array name
        ArraySetAsSeries(symbolsData[i].rates, true);  // Updated array name
        
        // Verify if symbol exists
        if(!SymbolSelect(symbolsData[i].symbol, true)) {  // Updated array name
            Print("Erro: Símbolo ", symbolsData[i].symbol, " não encontrado");  // Updated array name
            return INIT_FAILED;
        }
    }
    
    tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), painel.getShortCurrencies());
    
    if(!painel.OnInit(myMagicNumber.magicNumber)) 
        return INIT_FAILED;
        
    trade.SetExpertMagicNumber(tradeInfos.iMagicNumber);
    EventSetTimer(1);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    for(int i = 0; i < ArraySize(symbolsData); i++) {  // Updated array name
        ObjectsDeleteAll(0, "h9k_line_" + symbolsData[i].symbol + "_", 0, -1);  // Updated array name
        ArrayFree(symbolsData[i].rates);  // Updated array name
    }
    
    ArrayFree(symbolsData);  // Updated array name
    painel.Destroy(reason);
    delete &tradeInfos;
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    painel.OnTimer();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    painel.PanelChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    painel.OnTick();
    
    bool newBar = isNewBar();
    
    MqlDateTime setTime;
    datetime currentTime = TimeCurrent();
    
    TimeToStruct(currentTime, setTime);
    setTime.hour = (int)StringToInteger(StringSubstr(iTimeStart, 0, 2));
    setTime.min  = (int)StringToInteger(StringSubstr(iTimeStart, 3, 2));
    setTime.sec  = (int)StringToInteger(StringSubstr(iTimeStart, 6, 2));
    
    vStartTime = StructToTime(setTime);
    datetime _end_of_day = StringToTime("17:30:00");
    
    // Process each currency pair
    for(int i = 0; i < ArraySize(symbolsData); i++) {  // Updated array name
        string currentSymbol = symbolsData[i].symbol;  // Updated array name
        
        if(TimeCurrent() >= _end_of_day) {
            closeAllOpenOrders(currentSymbol);
            closeAllPositions(currentSymbol);
            continue;
        }
        
        if(currentTime < vStartTime) {
            setMaxMin(i);
            
            if(!iUseFixedTarget) {
                symbolsData[i].target = symbolsData[i].high - symbolsData[i].low;  // Updated array name
            } else {
                symbolsData[i].target = iFixedTarget;  // Updated array name
            }
            
            symbolsData[i].allowTrade = true;  // Updated array name
            symbolsData[i].setReversionOrders = false;  // Updated array name
            
            PlotN("h9k_line_" + currentSymbol + "_high", symbolsData[i].high, clrYellow);  // Updated array name
            PlotN("h9k_line_" + currentSymbol + "_low", symbolsData[i].low, clrBrown);  // Updated array name
            ChartRedraw();
            
            continue;
        }
        
        int _total_positions = HasPosition(myMagicNumber.magicNumber);
        
        if(_total_positions == 0 && symbolsData[i].setReversionOrders) {  // Updated array name
            closeAllOpenOrders(currentSymbol);
        }
        
        if(symbolsData[i].allowTrade && _total_positions == 0) {  // Updated array name
            trade.BuyStop(iAmount, symbolsData[i].high, currentSymbol, symbolsData[i].low,   // Updated array name
                         symbolsData[i].high + symbolsData[i].target, ORDER_TIME_DAY, 0, "Rompimento da máxima " + currentSymbol);  // Updated array name
            trade.SellStop(iAmount, symbolsData[i].low, currentSymbol, symbolsData[i].high,   // Updated array name
                          symbolsData[i].low - symbolsData[i].target, ORDER_TIME_DAY, 0, "Rompimento da mínima " +  currentSymbol);  // Updated array name
            symbolsData[i].allowTrade = false;  // Updated array name
        } 
        else if(_total_positions == 1 && !symbolsData[i].setReversionOrders) {  // Updated array name
            processReversionOrders(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Process reversion orders for a specific currency                  |
//+------------------------------------------------------------------+
void processReversionOrders(int currencyIndex) {
    CPositionInfo _pos;
    string currentSymbol = symbolsData[currencyIndex].symbol;  // Updated array name
    
    if(_pos.Magic() == myMagicNumber.magicNumber && _pos.Symbol() == currentSymbol) {
        if(_pos.PositionType() == POSITION_TYPE_BUY && _pos.Volume() == iAmount) {
            closeSellStopOrders(currentSymbol);
            if(iReversion)
                trade.SellStop(2 * iAmount, _pos.StopLoss(), currentSymbol, _pos.PriceOpen(), 
                             _pos.StopLoss() - symbolsData[currencyIndex].target, ORDER_TIME_DAY, 0, "Reversão da compra  " +  currentSymbol );  // Updated array name
        } 
        else if(_pos.PositionType() == POSITION_TYPE_SELL && _pos.Volume() == iAmount) {
            closeBuyStopOrders(currentSymbol);
            if(iReversion)
                trade.BuyStop(2 * iAmount, _pos.StopLoss(), currentSymbol, _pos.PriceOpen(), 
                            _pos.StopLoss() + symbolsData[currencyIndex].target, ORDER_TIME_DAY, 0, "Reversão da venda "  + currentSymbol);  // Updated array name
        }
        
        symbolsData[currencyIndex].setReversionOrders = true;  // Updated array name
    }
}

//+------------------------------------------------------------------+
//| Close all positions for a specific symbol                         |
//+------------------------------------------------------------------+
void closeAllPositions(string symbol) {
    if(HasPosition(myMagicNumber.magicNumber) == 0) return;
    
    CPositionInfo _pos;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        _pos.SelectByIndex(i);
        if(_pos.Magic() == myMagicNumber.magicNumber && _pos.Symbol() == symbol) {
            trade.PositionClose(_pos.Ticket());
        }
    }
}

//+------------------------------------------------------------------+
//| Close all open orders for a specific symbol                       |
//+------------------------------------------------------------------+
void closeAllOpenOrders(string symbol) {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetInteger(ORDER_MAGIC) != myMagicNumber.magicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) == symbol) {
            trade.OrderDelete(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Close buy stop orders for a specific symbol                       |
//+------------------------------------------------------------------+
void closeBuyStopOrders(string symbol) {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetInteger(ORDER_MAGIC) != myMagicNumber.magicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) == symbol && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) {
            trade.OrderDelete(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Close sell stop orders for a specific symbol                      |
//+------------------------------------------------------------------+
void closeSellStopOrders(string symbol) {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetInteger(ORDER_MAGIC) != myMagicNumber.magicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) == symbol && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) {
            trade.OrderDelete(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Set max and min values for a specific currency                    |
//+------------------------------------------------------------------+
void setMaxMin(int currencyIndex) {
    MqlDateTime setTime;
    datetime currentTime = TimeCurrent();
    TimeToStruct(currentTime, setTime);
    datetime startOfDay = currentTime - (currentTime % 86400);
    
    setTime.hour = (int)StringToInteger(StringSubstr(iTimeStart, 0, 2));
    setTime.min  = (int)StringToInteger(StringSubstr(iTimeStart, 3, 2));
    setTime.sec  = (int)StringToInteger(StringSubstr(iTimeStart, 6, 2));
    
    int _cp_rates = CopyRates(symbolsData[currencyIndex].symbol, PERIOD_M1, startOfDay,   // Updated array name
                             StructToTime(setTime), symbolsData[currencyIndex].rates);  // Updated array name
    
    if(_cp_rates <= 0) {
        Print("Falha ao copiar cotações para ", symbolsData[currencyIndex].symbol, ". Error ", GetLastError());  // Updated array name
        return;
    }
    
    symbolsData[currencyIndex].high = 0;  // Updated array name
    symbolsData[currencyIndex].low = 0;   // Updated array name
    
    for(int i = 0; i < _cp_rates; i++) {
        symbolsData[currencyIndex].high = symbolsData[currencyIndex].rates[i].high > symbolsData[currencyIndex].high ?   // Updated array name
                                       symbolsData[currencyIndex].rates[i].high : symbolsData[currencyIndex].high;  // Updated array name
        symbolsData[currencyIndex].low = (symbolsData[currencyIndex].low == 0 || symbolsData[currencyIndex].rates[i].low < symbolsData[currencyIndex].low) ?   // Updated array name
                                      symbolsData[currencyIndex].rates[i].low : symbolsData[currencyIndex].low;  // Updated array name
    }
}

//+------------------------------------------------------------------+
//| Plot horizontal line                                             |
//+------------------------------------------------------------------+
void PlotN(string name, double price, color lineColor = clrYellow) {
    if(ObjectFind(0, name) != -1) {
        ObjectSetDouble(0, name, OBJPROP_PRICE, price);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
    } else {
        if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) {
            Print("Erro ao criar a linha horizontal: ", GetLastError());
            return;
        }
        
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
    }
}