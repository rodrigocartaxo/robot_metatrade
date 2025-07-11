//+------------------------------------------------------------------+
//|                                                   H9k_YT_FVG.mq5 
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

#property copyright "H9k Trading Systems"
#property link      "https://www.youtube.com/@h9ktrades"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <.\Personal\H9k_Includes\H9k_libs_4.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>

enum ENUM_ON_OFF {
    enabled  = 1,       // Ativado
    disabled = 0        // Desativado
};

enum LOG_LEVEL {
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_INFO = 1,
    LOG_LEVEL_DEBUG = 2
};

//--- input parameters
input group "🕝 Janela Operacional"
input ENUM_ON_OFF i24h = disabled;   //Modo 24h (forex)
input string iHoraIni  = "09:05:00"; //Hora inicio
input string iHoraFim  = "17:30:00"; //Hora fim

input group "Configurações Básicas"
input double iAmount        = 1;     //Quantidade de Contratos
input double iStopLoss      = 100;   //Pontos para stop loss
input double iTakeProfit    = 130;   //Pontos para take profit
input LOG_LEVEL LogLevel     = LOG_LEVEL_INFO; // Nível de log exibido
input ENUM_ON_OFF MostrarLogs =  enabled;      // Mostrar logs detalhados
input group "Fair Value Gap"
input double iFVGBodyPercentage = 60;            //Percentual relativo do corpo
input ENUM_TIMEFRAMES iFVGTimeFrame = PERIOD_M5; //Tempo gráfico
input int iFVGATR = 10;                          //Período do ATR
input int iNumberCandles = 6;                      //Numero candels analise

// Parâmetros de Gerenciamento de Posição
input group "=== Gerenciamento de Posição ==="
input ENUM_ON_OFF GerenciarPosicoesAtivado   = enabled; // Ativar Gerenciamento de Posição
input int      PontosParaFechamentoParcial    = 50;  // Pontos para fechamento parcial
input double   PercentualFechamentoParcial    = 20.0; // Percentual a fechar por etapa
input int      NumeroMaximoFechamentosParciais= 5; // Número máximo de fechamentos parciais



CTrade trade;

int hATR;           //handle do ATR
double vATR[];      //variável com valores do ATR
MqlRates rates[];   //variável com valores das barras
int fechoParcialContador = 0;
double volumeOriginal = 0;

double const price_step = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE ); //Contém o valor do tick

ulong iMagicNumber   = 0;    //Identificador = 0.0; 

MyMagicNumber myMagicNumber;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    PrintFormat("[%I64d] Inicializando...", iMagicNumber);
    PrintFormat("[%I64d] Build date: %s", iMagicNumber, (string)__DATETIME__);
    
    iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME), _Symbol); 
    
    // Configurações de trading
    trade.SetExpertMagicNumber(iMagicNumber);
    trade.SetDeviationInPoints(10); // Desvio máximo do preço
    trade.SetTypeFilling(ORDER_FILLING_RETURN); // Tipo de preenchimento
    trade.SetExpertMagicNumber(iMagicNumber); // Número mágico do EA
    trade.LogLevel(LOG_LEVEL_ALL); // Nível de log
    trade.SetAsyncMode(false); // Modo síncrono para garantir execução correta
    
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(vATR, true);
    
    
      
    
    hATR = iATR(_Symbol, iFVGTimeFrame, iFVGATR);
    if(hATR == INVALID_HANDLE) return INIT_FAILED;
    
    PrintFormat("[%I64d] sucesso.", iMagicNumber);    
    return(INIT_SUCCEEDED);
}
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

    if(hATR != INVALID_HANDLE)
        IndicatorRelease(hATR);
    
    PrintFormat("[%I64d] desligando.", iMagicNumber);   
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    static int last_entry_bar;
    //bool newBar = isNewBar();
    bool isBuy = false, isSell = false;
    double price = 0;

    if (!i24h && !allowed_by_hour(iHoraIni, iHoraFim)) {
        closeAllOpenOrders(trade, iMagicNumber);
        closeAllPositions(trade, iMagicNumber);
        return;
    }
    
    if(HasPosition(iMagicNumber) > 0) { //função da lib do canal
        return;
    }
    
    // Gerenciar posições abertas
    if(GerenciarPosicoesAtivado == enabled){
        GerenciarPosicoesAbertas();
    }
    
    //Procura nas últimas barras o último FVG encontrado
    if (CopyRates(_Symbol, iFVGTimeFrame, 0, 25, rates) <= 0) return;
    if (CopyBuffer(hATR, 0, 0, 3, vATR) <= 0) return;
    
    for(int i = 0; i < iNumberCandles; i++) {
        
        int _vMiddleBarIndex = Bars(_Symbol, iFVGTimeFrame, 0, rates[i+2].time);
        
        //Invalidar o fair value gap se ele foi acionado uma vez
        if (last_entry_bar > 0 && _vMiddleBarIndex <= last_entry_bar) {
            return;
        }
        
        double vBodySize   = MathAbs(rates[i+2].open - rates[i+2].close); //tamanho do corpo do candle de referência
        double vCandleSize = rates[i+2].high - rates[i+2].low;            //tamanho total do candle de referência
        double vMidCandle  = (rates[i+2].high + rates[i+2].low)/2;        //meio do candle de referência
        
        if (vCandleSize > 0 && (vBodySize/vCandleSize < iFVGBodyPercentage/100 || vCandleSize < vATR[0])) {
            if (has_open_order(iMagicNumber) == 0) ObjectsDeleteAll(0, "H9K_FVG_LINE_", 0, -1);
            continue;
        }
        
        if (rates[i+1].low > vMidCandle && rates[i+3].high < vMidCandle && rates[i+2].close > rates[i+2].open) {
            isBuy = true;
            isSell = false;
            price = roundPriceH9K((rates[i+3].high + rates[i+1].low)/2, price_step);
            SetHL("H9K_FVG_LINE_High", rates[i+3].high, clrGreen);
            SetHL("H9K_FVG_LINE_Low", rates[i+1].low, clrGreen);
            last_entry_bar = _vMiddleBarIndex;
            break;        
        } else if (rates[i+1].high < vMidCandle && rates[i+3].low > vMidCandle && rates[i+2].close < rates[i+2].open) {
            isBuy = false;
            isSell = true;
            price = roundPriceH9K((rates[i+1].high + rates[i+3].low)/2, price_step);
            SetHL("H9K_FVG_LINE_High", rates[i+1].high, clrRed);
            SetHL("H9K_FVG_LINE_Low", rates[i+3].low, clrRed);
            last_entry_bar = _vMiddleBarIndex;
            break;
        } 
        
    }
    
    double _bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
    double _ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
    
    if (isBuy && _ask > price) {
        
        if (has_open_order(iMagicNumber) && !has_order_at(price, iMagicNumber))
            closeAllOpenOrders(trade, iMagicNumber);

        if (!has_open_order(iMagicNumber))
            trade.BuyLimit(iAmount, price, _Symbol, price - iStopLoss, price + iTakeProfit, ORDER_TIME_DAY, 0, "FVG Compra");
            
    } else if (isSell && _bid < price) {
    
        if (has_open_order(iMagicNumber) && !has_order_at(price, iMagicNumber))
            closeAllOpenOrders(trade, iMagicNumber);
            
        if (!has_open_order(iMagicNumber))    
            trade.SellLimit(iAmount, price, _Symbol, price + iStopLoss, price - iTakeProfit, ORDER_TIME_DAY, 0, "FVG Venda");
    } else {
        closeAllOpenOrders(trade, iMagicNumber);
        ObjectsDeleteAll(0, "H9K_FVG_LINE_", 0, -1);        
    }
  
}

//+------------------------------------------------------------------+
//| Gerencia posições abertas e fechamentos parciais                  |
//+------------------------------------------------------------------+
void GerenciarPosicoesAbertas()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == iMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = 0;
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double currentVolume = PositionGetDouble(POSITION_VOLUME);
                
                if(type == POSITION_TYPE_BUY)
                {
                    currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Use BID for buy positions
                }
                else if(type == POSITION_TYPE_SELL)
                {
                    currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Use ASK for sell positions
                }
                
                double profitPoints = 0;
                if(type == POSITION_TYPE_BUY)
                {
                    profitPoints = (currentPrice - openPrice) / _Point;
                }
                else if(type == POSITION_TYPE_SELL)
                {
                    profitPoints = (openPrice - currentPrice) / _Point;
                }
                
                // Check for partial close
                if(profitPoints >= (fechoParcialContador + 1) * PontosParaFechamentoParcial)
                {
                    if(fechoParcialContador < NumeroMaximoFechamentosParciais)
                    {
                        double volumeToClose = currentVolume * (PercentualFechamentoParcial / 100.0);
                        LogMsg("DEBUG: Initial volumeToClose: " + DoubleToString(volumeToClose, 8) + ", currentVolume: " + 
                         DoubleToString(currentVolume, 8) + ", PercentualFechamentoParcial: " + 
                         DoubleToString(PercentualFechamentoParcial, 2), LOG_LEVEL_DEBUG);

                        // Normalize volume to ensure it's valid
                        volumeToClose = NormalizeDouble(volumeToClose, 2); // Assuming 2 decimal places for volume
                        LogMsg("DEBUG: volumeToClose after NormalizeDouble: " + DoubleToString(volumeToClose, 8), LOG_LEVEL_DEBUG);
                        
                        // Ensure volume is at least minimum allowed volume and a multiple of step
                        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                        double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                        LogMsg("DEBUG: minVolume: " + DoubleToString(minVolume, 8) + ", volumeStep: " + DoubleToString(volumeStep, 8), LOG_LEVEL_DEBUG);
                        
                        if(volumeToClose < minVolume)
                        {
                            volumeToClose = minVolume;
                            LogMsg("DEBUG: volumeToClose adjusted to minVolume: " + DoubleToString(volumeToClose, 8), LOG_LEVEL_DEBUG);
                        }
                        
                        // Adjust volume to be a multiple of volumeStep
                        volumeToClose = MathRound(volumeToClose / volumeStep) * volumeStep;
                        LogMsg("DEBUG: volumeToClose after adjusting for volumeStep: " + DoubleToString(volumeToClose, 8), LOG_LEVEL_DEBUG);

                        // Ensure calculated volume does not exceed current position volume
                        if (volumeToClose > currentVolume) {
                            volumeToClose = currentVolume;
                            LogMsg("DEBUG: volumeToClose adjusted to not exceed currentVolume: " + DoubleToString(volumeToClose, 8), LOG_LEVEL_DEBUG);
                        }

                        if(trade.PositionClosePartial(ticket, volumeToClose))
                        {
                            fechoParcialContador++;
                            LogMsg("INFO: Fechamento parcial: " + DoubleToString(volumeToClose, 2) + " a " + DoubleToString(currentPrice, _Digits) + ". Etapa: " + IntegerToString(fechoParcialContador), LOG_LEVEL_INFO);
                        }
                        else
                        {
                            LogMsg("ERRO: Falha ao fechar parcial da posição " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode()), LOG_LEVEL_ERROR);
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Função para log com nível                                        |
//+------------------------------------------------------------------+
void LogMsg(string mensagem, LOG_LEVEL nivel)
{
    if(MostrarLogs == enabled && nivel <= LogLevel)
    {
        Print(mensagem);
    }
}


//+------------------------------------------------------------------+
