//+------------------------------------------------------------------+
//| FVG.mq5                                                           |
//| Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader.       |
//| https://youtube.com/@ForexAlgo-Trader?                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader"
#property link      "https://youtube.com/@ForexAlgo-Trader?"
#property version   "1.00"


// Includes
#include <Trade/Trade.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>

// Global Variables and Constants
#define FVG_Prefix  "FVG REC "
#define CLR_UP      clrLime
#define CLR_DOWN    clrRed

CTrade obj_Trade;
MyCtrader trade;


// Configuration
int minPts = 100;
int FVG_Rec_Ext_Bars = 30;

// Arrays for storing FVG data
string    totalFVGs[];
int       barINDICES[];
datetime  barTIMES[];
bool      signalFVGs[];
MyPainel painel;
MyMagicNumber myMagicNumber;

TraderInfos tradeInfos;


void OnDeinit(const int reason){
       
      painel.Destroy(reason);  
      EventKillTimer();
   
 }
//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {

     tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),StringSubstr(_Symbol,0,3));
     tradeInfos.symbol = _Symbol;
   
    if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   
    Print("Serviço " + MQLInfoString(MQL_PROGRAM_NAME) + "  " + (string)tradeInfos.iMagicNumber);
    
    int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    
    Print("Total Visible Bars On Chart = ", visibleBars);
    
    EventSetTimer(1); 
    
    // Initialize arrays if no rectangles exist
    if (ObjectsTotal(0, 0, OBJ_RECTANGLE) == 0) {
        Print("NO FVGs, resizing storage arrays to 0 now!!!");
        ArrayResize(totalFVGs, 0);
        ArrayResize(barINDICES, 0);
        ArrayResize(signalFVGs, 0);
    }
    
    // Clear existing FVG objects
    ObjectsDeleteAll(0, FVG_Prefix);
    
    // Scan for FVGs
    for (int i = 0; i <= visibleBars; i++) {
        // Calculate gaps
        double low0 = iLow(_Symbol, _Period, i);
        double high2 = iHigh(_Symbol, _Period, i + 2);
        double gap_L0_H2 = NormalizeDouble((low0 - high2) / _Point, _Digits);
        
        double high0 = iHigh(_Symbol, _Period, i);
        double low2 = iLow(_Symbol, _Period, i + 2);
        double gap_H0_L2 = NormalizeDouble((low2 - high0) / _Point, _Digits);
        
        // Check for FVG conditions
        bool FVG_UP = low0 > high2 && gap_L0_H2 > minPts;
        bool FVG_DOWN = low2 > high0 && gap_H0_L2 > minPts;
        
        if (FVG_UP || FVG_DOWN) {
            Print("Bar Index FVG = ", i + 1, " >>> ", gap_L0_H2);
            
            // Calculate FVG parameters
            datetime time1 = iTime(_Symbol, _Period, i + 1);
            double price1 = FVG_UP ? high2 : high0;
            datetime time2 = time1 + PeriodSeconds(_Period) * FVG_Rec_Ext_Bars;
            double price2 = FVG_UP ? low0 : low2;
            string fvgNAME = FVG_Prefix + "(" + TimeToString(time1) + ")";
            color fvgClr = FVG_UP ? CLR_UP : CLR_DOWN;
            
            // Create FVG rectangle
            CreateRec(fvgNAME, time1, price1, time2, price2, fvgClr);
            
            // Update arrays
            int oldSize = ArraySize(totalFVGs);
            ArrayResize(totalFVGs, oldSize + 1);
            ArrayResize(barINDICES, oldSize + 1);
            
            totalFVGs[oldSize] = fvgNAME;
            barINDICES[oldSize] = i + 1;
            
            Print("Array sizes - Old: ", oldSize, " New: ", ArraySize(totalFVGs));
            ArrayPrint(totalFVGs);
            ArrayPrint(barINDICES);
        }
    }
    
    // Process existing FVGs
    for (int i = ArraySize(totalFVGs) - 1; i >= 0; i--) {
        string objName = totalFVGs[i];
        int barIndex = barINDICES[i];
        
        // Get FVG properties
        string fvgNAME = ObjectGetString(0, objName, OBJPROP_NAME);
        datetime timeSTART = (datetime)ObjectGetInteger(0, fvgNAME, OBJPROP_TIME, 0);
        datetime timeEND = (datetime)ObjectGetInteger(0, fvgNAME, OBJPROP_TIME, 1);
        double fvgLOW = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 0);
        double fvgHIGH = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 1);
        color fvgColor = (color)ObjectGetInteger(0, fvgNAME, OBJPROP_COLOR);
        
        Print("FVG CLR = ", fvgColor);
        Print(fvgNAME, " >TS: ", timeSTART, " >TE: ", timeEND, " NO: ", barIndex);
        
        // Check for FVG validity
        for (int k = barIndex - 1; k >= (barIndex - FVG_Rec_Ext_Bars); k--) {
            datetime barTime = iTime(_Symbol, _Period, k);
            double barLow = iLow(_Symbol, _Period, k);
            double barHigh = iHigh(_Symbol, _Period, k);
            
            Print("Bar No = ", k, " > Time: ", barTime);
            
            if (k == 0) {
                Print("FVG Overflow Detected @ bar ", fvgNAME);
                UpdateRec(fvgNAME, timeSTART, fvgLOW, barTime, fvgHIGH);
                break;
            }
            
            if ((fvgColor == CLR_UP && barLow < fvgLOW) ||
                (fvgColor == CLR_DOWN && barHigh > fvgHIGH)) {
                Print("Cut Off @ bar no ", k, " of Time: ", barTime);
                UpdateRec(fvgNAME, timeSTART, fvgLOW, barTime, fvgHIGH);
                break;
            }
        }
    }
    
    // Clear arrays
    ArrayResize(totalFVGs, 0);
    ArrayResize(barINDICES, 0);
    
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
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
     painel.OnTick();
  
    // Scan for new FVGs
    for (int i = 0; i <= FVG_Rec_Ext_Bars; i++) {
        double low0 = iLow(_Symbol, _Period, i + 1);
        double high2 = iHigh(_Symbol, _Period, i + 2 + 1);
        double gap_L0_H2 = NormalizeDouble((low0 - high2) / _Point, _Digits);
        
        double high0 = iHigh(_Symbol, _Period, i + 1);
        double low2 = iLow(_Symbol, _Period, i + 2 + 1);
        double gap_H0_L2 = NormalizeDouble((low2 - high0) / _Point, _Digits);
        
        bool FVG_UP = low0 > high2 && gap_L0_H2 > minPts;
        bool FVG_DOWN = low2 > high0 && gap_H0_L2 > minPts;
        
        if (FVG_UP || FVG_DOWN) {
            datetime time1 = iTime(_Symbol, _Period, i + 1 + 1);
            double price1 = FVG_UP ? high2 : high0;
            datetime time2 = time1 + PeriodSeconds(_Period) * FVG_Rec_Ext_Bars;
            double price2 = FVG_UP ? low0 : low2;
            string fvgNAME = FVG_Prefix + "(" + TimeToString(time1) + ")";
            color fvgClr = FVG_UP ? CLR_UP : CLR_DOWN;
            
            if (ObjectFind(0, fvgNAME) < 0) {
                CreateRec(fvgNAME, time1, price1, time2, price2, fvgClr);
                
                int oldSize = ArraySize(totalFVGs);
                ArrayResize(totalFVGs, oldSize + 1);
                ArrayResize(barTIMES, oldSize + 1);
                ArrayResize(signalFVGs, oldSize + 1);
                
                totalFVGs[oldSize] = fvgNAME;
                barTIMES[oldSize] = time1;
                signalFVGs[oldSize] = false;
                
                ArrayPrint(totalFVGs);
                ArrayPrint(barTIMES);
                ArrayPrint(signalFVGs);
            }
        }
    }
    
    // Process existing FVGs
    for (int j = ArraySize(totalFVGs) - 1; j >= 0; j--) {
        string fvgNAME = totalFVGs[j];
        bool fvgExist = false;
        
        double fvgLow = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 0);
        double fvgHigh = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 1);
        color fvgColor = (color)ObjectGetInteger(0, fvgNAME, OBJPROP_COLOR);
        
        // Check FVG existence
        for (int k = 1; k <= FVG_Rec_Ext_Bars; k++) {
            double barLow = iLow(_Symbol, _Period, k);
            double barHigh = iHigh(_Symbol, _Period, k);
            
            if (barLow == fvgLow || barHigh == fvgLow) {
                fvgExist = true;
                break;
            }
        }
        
        // Check for trading signals
        double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
        double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
        double price_step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        if (fvgColor == CLR_DOWN && Bid > fvgHigh && !signalFVGs[j]) {
            Print("SELL SIGNAL For (", fvgNAME, ") Now @ ", Bid,MQLInfoString(MQL_PROGRAM_NAME));
            //obj_Trade.Sell(1, _Symbol, Bid, 0, fvgLow,MQLInfoString(MQL_PROGRAM_NAME));
            double sl = roundPriceH9K(fvgHigh - (fvgHigh * iStopLossPercent/100), price_step);
            double tp = roundPriceH9K(fvgLow + (fvgLow * iTakeProfitPercent/100), price_step);
            
            tradeInfos.amount   = roundPriceH9K(Bid,_Digits);
            tradeInfos.order_type = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = ORDER_TIME_GTC;
            tradeInfos.stop_loss = 0;//sl ;//roundPriceH9K(fvgHigh,price_step);  //0; 
            tradeInfos.take_profit =  tp; //roundPriceH9K(fvgLow,price_step); 
            tradeInfos.lot_size = CalcularTamanhoLote(_Symbol,tradeInfos.take_profit,tradeInfos.amount);
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ _Symbol;
            trade.sendOrder(tradeInfos); 
            
            
            
            signalFVGs[j] = true;
            ArrayPrint(totalFVGs, _Digits, " [< >] ");
            ArrayPrint(signalFVGs, _Digits, " [< >] ");
        }
        else if (fvgColor == CLR_UP && Ask < fvgLow && !signalFVGs[j]) {
            Print("BUY SIGNAL For (", fvgNAME, ") Now @ ", Ask);
            //obj_Trade.Buy(1, _Symbol, Ask, 0, fvgHigh,MQLInfoString(MQL_PROGRAM_NAME));
            double sl = roundPriceH9K(fvgLow + (fvgLow * iStopLossPercent/100), price_step);
            double tp = roundPriceH9K(fvgHigh - (fvgHigh * iTakeProfitPercent/100), price_step);           
           
            tradeInfos.amount   = roundPriceH9K(Ask,_Digits);
            tradeInfos.order_type = ORDER_TYPE_BUY;
            tradeInfos.order_type_time = ORDER_TIME_GTC;
            tradeInfos.stop_loss = 0;  //roundPriceH9K(fvgLow,price_step);//0; 
            tradeInfos.take_profit = tp; //roundPriceH9K(fvgHigh,price_step); 
            tradeInfos.lot_size = CalcularTamanhoLote(_Symbol,tradeInfos.take_profit,tradeInfos.amount);
            tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ _Symbol;
            trade.sendOrder(tradeInfos); 
            
            
            signalFVGs[j] = true;
            ArrayPrint(totalFVGs, _Digits, " [< >] ");
            ArrayPrint(signalFVGs, _Digits, " [< >] ");
        }
        
        // Remove invalid FVGs
        if (!fvgExist) {
            bool removeName = ArrayRemove(totalFVGs, 0, 1);
            bool removeTime = ArrayRemove(barTIMES, 0, 1);
            bool removeSignal = ArrayRemove(signalFVGs, 0, 1);
            
            if (removeName && removeTime && removeSignal) {
                Print("Success removing the FVG DATA from arrays. New Data as below:");
                Print("FVGs: ", ArraySize(totalFVGs), " TIMEs: ", ArraySize(barTIMES),
                      " SIGNALs: ", ArraySize(signalFVGs));
                ArrayPrint(totalFVGs);
                ArrayPrint(barTIMES);
                ArrayPrint(signalFVGs);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                   |
//+------------------------------------------------------------------+
void CreateRec(string objName, datetime time1, double price1,
               datetime time2, double price2, color clr) {
    if (ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
        ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
        ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
        ObjectSetInteger(0, objName, OBJPROP_FILL, true);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        ChartRedraw(0);
    }
}

void UpdateRec(string objName, datetime time1, double price1,
               datetime time2, double price2) {
    if (ObjectFind(0, objName) >= 0) {
        ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
        ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
        ChartRedraw(0);
    }
}

//+------------------------------------------------------------------+
//| Calcula tamanho do lote baseado na porcentagem do take profit    |
//+------------------------------------------------------------------+
double CalcularTamanhoLote(string simbolo, double takeProfit, double precoEntrada)
{
   // Calcular a porcentagem de variação entre o preço de entrada e o take profit
   double porcentagemVariacao = 0;
   
   if(precoEntrada > 0)
   {
      if(takeProfit > precoEntrada) // Para posições de compra
         porcentagemVariacao = ((takeProfit - precoEntrada) / precoEntrada) * 100.0;
      else // Para posições de venda
         porcentagemVariacao = ((precoEntrada - takeProfit) / precoEntrada) * 100.0;
   }
   
   // Determinar o tamanho do lote com base na porcentagem de variação
   double tamanhoLote = 0;
   
   // Faixas de porcentagem e tamanhos de lote correspondentes
   // Personalize estas faixas conforme necessário para sua estratégia
   
   
   if(porcentagemVariacao < 0.2)
      tamanhoLote =  SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MIN) * 2.0 ; // Para variações menores que 2%
   else if(porcentagemVariacao < 0.5)
      tamanhoLote = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MIN) * 1.0; // Para variações entre 2% e 5%
   else if(porcentagemVariacao < 1.0)
      tamanhoLote = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MIN) * 1.0; // Para variações entre 5% e 8%
   else if(porcentagemVariacao < 8.0)
      tamanhoLote = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MIN) * 1.0; // Para variações entre 8% e 12%
  
   else
      tamanhoLote = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MIN); // Para variações maiores que 12%
   
   // Ajustar para os limites da corretora
   double loteMinimo = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MIN);
   double loteMaximo = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_MAX);
   double loteStep = SymbolInfoDouble(simbolo, SYMBOL_VOLUME_STEP);
   
   // Arredondar para o múltiplo mais próximo de loteStep
   tamanhoLote = MathRound(tamanhoLote / loteStep) * loteStep;
   
   // Garantir que está entre os limites permitidos
   tamanhoLote = MathMax(tamanhoLote, loteMinimo);
   tamanhoLote = MathMin(tamanhoLote, loteMaximo);
   
   // Imprimir para depuração
   Print("Porcentagem de variação calculada: ", DoubleToString(porcentagemVariacao, 2), "%");
   Print("Tamanho do lote atribuído: ", DoubleToString(tamanhoLote, 2));
   
   return tamanhoLote;
}