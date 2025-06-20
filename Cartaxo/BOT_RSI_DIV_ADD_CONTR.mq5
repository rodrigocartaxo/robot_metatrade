//+------------------------------------------------------------------+
//|                                              H9k_YT_Live_RSI.mq5 
//|                                                       H9k Trades 
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

#property copyright "H9k Trades"
#property link      "https://www.youtube.com/@h9ktrades"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <.\Personal\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>




input group "::::::::::::::: Basic Settings ::::::::::::::::::"
//input ENUM_ON_OFF iClosePositions  = enabled; //Botão de clear deve zerar posições
input ENUM_ORDER_TYPE_TIME iOrderType = ORDER_TIME_GTC; //Tipo de ordem
input ENUM_ON_OFF iDebug              = off;       //Modo de depuração

input group "::: Parâmetros do RSI"
input double iRSI_OverSold   = 30; // Valor para Sobre Vendido
input double iRSI_OverBought = 70; // Valor para Sobre Comprado
input ENUM_TIMEFRAMES iRSI_TimeFrame = PERIOD_M30; //Timeframe
input int iRSI_Period = 14; //Período
input string iRSI_percentages = "0.5,1,1.5,2"; //Percentuais para aumentar posição
input int iAmount = 1; //QTD

//double price_step = SymbolInfoDouble( Symbol(), SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick

MyCtrader trade;


string vPercentages[];
int handle_RSI = INVALID_HANDLE;
double signal[]; 

TraderInfos tradeInfos;
MyMagicNumber myMagicNumber;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

    Print("Inicializando...");    
    PrintFormat("Build date: %s", (string)__DATETIME__);
    
    long h9k_account = AccountInfoInteger(ACCOUNT_LOGIN);
    string h9k_broker = AccountInfoString(ACCOUNT_COMPANY);
    
    PrintFormat("Trading on: %I64d : %s", h9k_account, h9k_broker);
    
    //_testMode = MQLInfoInteger(MQL_TESTER);
    tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), currencies);
    
    trade.SetExpertMagicNumber(tradeInfos.iMagicNumber);
      
    Print("EA " + MQLInfoString(MQL_PROGRAM_NAME)+ " inicializado com sucesso : "+ (string)tradeInfos.iMagicNumber);
    
    StringSplit(iRSI_percentages, StringGetCharacter(",", 0), vPercentages);
    
    handle_RSI = iCustom(_Symbol,_Period,"Market//RSI Divergence Indicator MT5");
      
      
    if (handle_RSI == INVALID_HANDLE){
      Print(" UNABLE TO INITILAZE  ");
      return(INIT_FAILED);
    }
      
    ArraySetAsSeries(signal,true);
    
    PrintFormat("[%d] Inicializado com sucesso!", tradeInfos.iMagicNumber);    

   return(INIT_SUCCEEDED);
}



//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   
    ArrayFree(signal);
    
     if(handle_RSI!= INVALID_HANDLE  ){
      IndicatorRelease(handle_RSI);
     }  
    Print("Serviço finalizado");
   
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {

    bool newBar = isNewBar();
    /*int _length_loop = ArraySize(vPercentages) - OpenOrdersCount(iMagicNumber)<= 0?ArraySize(vPercentages)
                      :ArraySize(vPercentages) - OpenOrdersCount(iMagicNumber);*/
    
    int open_positions = HasPosition(tradeInfos.iMagicNumber);
    int open_orders    = OpenOrdersCount(tradeInfos.iMagicNumber);
    
    double price_step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double _bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
    double _ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
    
    if (CopyBuffer(handle_RSI,1,0,1,signal)<1){
       Print(" UNABLE TO INITILAZE ERROR ON COPY BUFFER  ");
       return;
   }
   
   ArraySetAsSeries(signal,true);
   
   bool isBuy = signal[0]==1;
   bool isSell = signal[0]==-1;
    
    if (isBuy && open_positions == 0) {
        trade.Buy(iAmount, _Symbol, 0, 0, 0, MQLInfoString(MQL_PROGRAM_NAME)+ " "+_Symbol);
        for(int i = 0; i < ArraySize(vPercentages); i++) {
            double _oprice = roundPriceH9K(_ask * (100 - (double)vPercentages[i])/100, price_step);
            double tp = roundPriceH9K(_oprice + (_oprice * iTakeProfitPercent/100), price_step);
            string _comment = MQLInfoString(MQL_PROGRAM_NAME) + vPercentages[i];
            //double = trade.calcLots(info.amount - info.stop_loss),_Symbol);
            trade.BuyLimit(iAmount, _oprice, _Symbol, 0, tp, ORDER_TIME_GTC, 0, _comment);
            
        }
    } else if (isSell && open_positions == 0) {
        trade.Sell(iAmount, _Symbol, 0, 0, 0,  MQLInfoString(MQL_PROGRAM_NAME) + " "+_Symbol);
        for(int i = 0; i < ArraySize(vPercentages); i++) {
            double _oprice = roundPriceH9K(_bid * (100 + (double)vPercentages[i])/100, price_step);
            double tp = roundPriceH9K(_oprice - (_oprice * iTakeProfitPercent/100), price_step);
            string _comment =  MQLInfoString(MQL_PROGRAM_NAME)+ vPercentages[i];
            trade.SellLimit(iAmount, _oprice, _Symbol, 0, tp, ORDER_TIME_GTC, 0, _comment);
        }
    } else if (isSell && IsBought(tradeInfos.iMagicNumber)) {
        massClose();
    } else if (isBuy && IsSold(tradeInfos.iMagicNumber)) {
        massClose();        
    } else if (IsBought(tradeInfos.iMagicNumber) && (open_orders + open_positions) < ArraySize(vPercentages) + 1) {
       
        for(int i = (open_positions - 1); i <ArraySize(vPercentages); i++) {
            double _ref = getHighestPositionPrice(tradeInfos.iMagicNumber);
            double _oprice = roundPriceH9K(_ref * (100 - (double)vPercentages[i])/100, price_step);
            double tp = roundPriceH9K(_oprice + (_oprice * iTakeProfitPercent/100), price_step);
            string _comment = MQLInfoString(MQL_PROGRAM_NAME) + vPercentages[i];
            trade.BuyLimit(iAmount, _oprice, _Symbol, 0, tp, ORDER_TIME_GTC, 0, _comment);
        }
    } else if (IsSold(tradeInfos.iMagicNumber) && (open_orders + open_positions) < ArraySize(vPercentages) + 1) {
        
        for(int i = (open_positions - 1); i <ArraySize(vPercentages); i++) {
            double _ref = getLowestPositionPrice(tradeInfos.iMagicNumber);
            double _oprice = roundPriceH9K(_ref * (100 + (double)vPercentages[i])/100, price_step);
            double tp = roundPriceH9K(_oprice - (_oprice * iTakeProfitPercent/100), price_step);
            string _comment = MQLInfoString(MQL_PROGRAM_NAME)+ vPercentages[i];
            trade.SellLimit(iAmount, _oprice, _Symbol, 0, tp, ORDER_TIME_GTC, 0, _comment);
        }
    }
    
   
  }
  
void massClose() {
    Print("Close all positons"); 
    closeAllPositions(trade, tradeInfos.iMagicNumber);
    closeAllOpenOrders(trade, tradeInfos.iMagicNumber);
}

//+------------------------------------------------------------------+
