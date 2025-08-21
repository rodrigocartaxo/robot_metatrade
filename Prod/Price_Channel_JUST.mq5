//+------------------------------------------------------------------+
//|                                           Price_Channel_Alert_EA.mq5 |
//|                                                                      |
//|                                                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property description "Expert Advisor para Price Channel com configuração local"
#define     MVersion       "1.00"

// Inclusão de bibliotecas necessárias
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <.\Personal\H9k_Includes\H9k_libs_4.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\H9k_Includes\H9k_X_Panel.mqh>

#define ACCOUNT_MARGIN_MODE_NETTING 0
#define ACCOUNT_MARGIN_MODE_HEDGED  1

// Enumerações
enum ENUM_CHANNEL_LEVEL
{
    NIVEL_1 = 1,    // Nível 1 
    NIVEL_2 = 2,    // Nível 2 
    NIVEL_3 = 3     // Nível 3 
};


enum ENUM_SIM_NAO
{
    nao,  // Off
    sim   // On
};
enum ENUM_ORIGIN{
    OTHON,  // External
    VIANA   // Internal
};

// Enum para posição VWAP
enum ENUM_POSICAO_VWAP {
    VWAP_NEUTRO = 0,    // Preço próximo ao VWAP (zona neutra)
    VWAP_BULLISH = 1,   // Preço acima do VWAP (favorável para compra)
    VWAP_BEARISH = -1   // Preço abaixo do VWAP (favorável para venda)
};

// Enum para níveis de log
enum LOG_LEVEL {
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_INFO = 1,
    LOG_LEVEL_DEBUG = 2
};

//--- input parameters
input group " 🕝 Daytrade Window"
input ENUM_SIM_NAO i24h = nao; //Liga o modo 24h (forex)
input string iHoraIni  = "09:01:00"; //Hora inicio
input string iHoraFim  = "17:30:00"; //Hora fim
input ENUM_SIM_NAO AtivarInterval             = nao;      // Ativar Hora de pausa 
input string iHoraInterval1                   = "12:00"; //Hora Inicio Pausa
input string iHoraInterval2                   = "13:30"; //Hora Fim Pausa


// Parâmetros gerais
input group "=== Configurações Gerais ==="
input ENUM_TIMEFRAMES Periodo                 = PERIOD_M5;  // Período do Gráfico
input ENUM_CHANNEL_LEVEL NivelAtivo           = NIVEL_1;  // Nível do Canal a Exibir
//input double   Volume                         = 10;       // Alavacagem Lotes
input ENUM_SIM_NAO MostrarLogs                = sim;      // Mostrar logs detalhados
input LOG_LEVEL LogLevel                      = LOG_LEVEL_INFO; // Nível de log exibido
input ENUM_SIM_NAO MostrarPreco               = sim;     // Mostrar preço nas linhas
input int numeroLinhas                        =  40 ; //Numero de canais
// Parâmetro removido - não há mais origem externa 
input int DesvioMaximoPontos                  = 10; // Desvio máximo permitido (slippage) em pontos
input int percentualStopLoss                  = 10 ; //Percentual Stoploss x Breakeven ref. Canal
input string iConfSaidas                      = "2:20,6:80,2:120,1:400";
input string InstanceName                     = "PC1";
input int posbreakeven                         = 1; // Ativar Brreakeven posicoes restantes

input group "=== Take Profit Múltiplo ==="
input ENUM_SIM_NAO tpMultiplo = nao;           // Ativar TP Múltiplo
input double tpATRMultiplier = 2.5;            // Multiplicador ATR para TP2
input double tpRiskReward = 3.0;               // R:R para TP3
input double tpLongoMultiplier = 6.0;          // Multiplicador ATR para TP4 (Alvo Longo)
input int tpPercentual1 = 40;                  // % Volume TP1 (Canal)
input int tpPercentual2 = 30;                  // % Volume TP2 (ATR)
input int tpPercentual3 = 20;                  // % Volume TP3 (R:R)
input int tpPercentual4 = 10;                  // % Volume TP4 (Alvo Longo)


input group "=== Configurações Canais ==="
input int      EspessuraLinha                 = 1;      // Espessura das linhas
input ENUM_LINE_STYLE EstiloLinha             = STYLE_SOLID;  // Estilo das linhas



input group "=== Risk Management ==="
input ENUM_SIM_NAO riskManagement            = nao;   // Ativar Risk Management
input int    iDailyTarget                    = 10000;    // Meta de ganho 
input int    iLossTarget                     = 500;     // Loss máximo 
input double iDDTrigger                      = 300;     // Valor para ativar o drawdown
input double iDrawDown                       = 20;       // Percentual do valor para fechar posição


input group "Outros"
input ENUM_SIM_NAO iClosePositions = sim; //Botão de Pause deve zerar posições
input ENUM_SIM_NAO iPanel = sim;             //Painel

input group "=== Filtro VWAP ==="
input ENUM_SIM_NAO usarFiltroVWAP = sim;           // Ativar filtro VWAP
input ENUM_TIMEFRAMES timeframeVWAP = PERIOD_M5; // Timeframe para VWAP
input int candlesVWAP = 20;                         // Número de candles para VWAP
input double toleranciaVWAP = 0.0;                  // Tolerância do filtro (0 = automático)
input ENUM_SIM_NAO mostrarVWAP = sim;               // Mostrar linha VWAP no gráfico
input color corVWAP = clrMagenta;                   // Cor da linha VWAP
input int espessuraVWAP = 2;                        // Espessura da linha VWAP
input ENUM_SIM_NAO vwapRestritivo = nao;            // Filtro VWAP restritivo (só permite direção favorável)
input ENUM_SIM_NAO vwapLogDetalhado = nao;          // Log detalhado do filtro VWAP

input group "=== Trailing Stop ==="
input ENUM_SIM_NAO ativarTrailingStop = sim;       // Ativar Trailing Stop
input ENUM_SIM_NAO trailingAposBreakeven = sim;     // Trailing só após breakeven
input double distanciaTrailing = 2.0;               // Distância do trailing (em canais)
input double ativacaoTrailing = 1.0;                // Canal para ativar trailing
input ENUM_SIM_NAO trailingLogDetalhado = sim;      // Log detalhado do trailing


// Variáveis globais
double vMaxProfit;
string prefixoObjeto = "PriceChannel_";
double tickSize; // Tamanho do tick do ativo


MqlRates rates[];
MqlRates rateGatilho;

// Array para dados VWAP
MqlRates ratesVWAP[];

double linhasPreco[];

// Variáveis globais de trading
CTrade trade;
bool posicaoAberta = false;
ulong posicaoTicket = 0;


bool vTPTrigger = false;
bool vTargetLock = false;
bool vDDTriggerActive = false;

// Flag para evitar logs/fechamentos redundantes ao ativar o lock
bool vTargetLockLogDone = false;

// Locks e flags separados para cada evento
bool vTargetLockMeta = false;
bool vTargetLockLoss = false;
bool vTargetLockDrawdown = false;
bool vTargetLockMetaLogDone = false;
bool vTargetLockLossLogDone = false;
bool vTargetLockDrawdownLogDone = false;
// Parâmetro removido

ulong MagicNumber = 0; 

MyMagicNumber myMagicNumber;

// Variáveis globais de estatísticas
int qtdOperacoes = 0;
int qtdGain = 0;
int qtdLoss = 0;

datetime ultimoCandleEntrada = 0; // Trava para apenas uma entrada por candle de gatilho
datetime ultimoDiaConfig = 0; // Novo: controle do último dia de configuração

bool ordensAberta = false;

double nivelBase = 0.0;

// Variáveis globais para breakeven por canal
int canalEntradaIndex = -1;
double alvo_breakeven = 0.0;
bool breakevenAtivado = false;
double precoEntrada = 0.0;

CH9kPanel MyPanel;
bool vPauseEA = false;      // variável de controle para pausar/iniciar estratégia



//+------------------------------------------------------------------+
//| Estrutura para armazenar configurações de nível                    |
//+------------------------------------------------------------------+
struct NivelCanal {
    double precoBase;
    double incrementoTick;
    color corBase;
    string prefixo;
    int nivel;
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar configurações de saidas                 |
//+------------------------------------------------------------------+
struct ConfNivelSaidas {
    double qtdContratos;
    double percentSaida;
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar configurações de saidas  modo   HEDGING |
//+------------------------------------------------------------------+
struct IndNivelSaidasHEDGING {
    double qtdContratos;
    double valorSaida;
    bool processada;
};


//+------------------------------------------------------------------+
//| Estrutura para armazenar configurações de saidas modo   HEDGING  |
//+------------------------------------------------------------------+
struct ConfNivelSaidasHEDGING {
    ulong numeroTicket;
    ENUM_POSITION_TYPE posType;  
    IndNivelSaidasHEDGING confSaidasHEDGING [];
};


// Estrutura removida - não há mais dados externos

//+------------------------------------------------------------------+
//| Estrutura para armazenar Take Profits múltiplos                   |
//+------------------------------------------------------------------+
struct TakeProfitMultiplo {
    double preco;
    double volume;
    int percentual;
    string descricao;
    bool ativo;
};

NivelCanal niveis[];
ConfNivelSaidas niveisSaidas[];
ConfNivelSaidasHEDGING niveisSaidasHEDGING;
//double Volume = 0.0;

// Variáveis para Trailing Stop
bool trailingStopAtivado = false;
double ultimoTrailingStop = 0.0;
int canalTrailingAtivado = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit(){
 
    string modo =  AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING?"NETTING":"HEDGING";
    
    LogMsg("Inciando EA em modo: " + modo , LOG_LEVEL_INFO);
    
    Comment("Price Channel EA - Configuração Local");
    
    ChartSetSymbolPeriod(0, _Symbol, Periodo);
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack); // Fundo preto
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrLightGreen); // Eixos, preço, tempo em verde claro
    ChartSetInteger(0, CHART_COLOR_VOLUME, clrGray); // Volume cinza
    ChartSetInteger(0, CHART_COLOR_GRID, clrDimGray); // Grid discreto
    ChartSetInteger(0,CHART_SHOW_GRID,false);
    ChartSetInteger(0,CHART_SHOW_VOLUMES,false);
    ChartSetInteger(0, CHART_AUTOSCROLL, true);
    ChartSetInteger(0, CHART_SHIFT, true);
    
    ResetLastError();
        
    if (AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO) {
        LogMsg("Este EA só pode ser executado em contas em DEMO.", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    MagicNumber = CalcularMagicNumber(MQLInfoString(MQL_PROGRAM_NAME), _Symbol); 
    
    
    
    // Salva o dia da configuração inicial
    ultimoDiaConfig = iTime(_Symbol, PERIOD_D1, 0);
    
    
    // Obter o tamanho do tick do ativo
    tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize == 0){
        LogMsg("ERRO: Falha ao obter o tamanho do tick do ativo!", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    LogMsg("Tamanho do tick do ativo " + _Symbol + ": " + DoubleToString(tickSize, _Digits), LOG_LEVEL_INFO);
    
    // Limpar objetos antigos
    LimparObjetos();
    
    
    
    
    caculaLinhasJust();
    
    CriarLinhasNivel();
    
    ChartRedraw(0);
    
    // Configurações de trading
    trade.SetDeviationInPoints(DesvioMaximoPontos); // Usa o valor configurado pelo usuário
    trade.SetTypeFilling(ORDER_FILLING_RETURN); // Tipo de preenchimento
    trade.SetExpertMagicNumber(MagicNumber); // Número mágico do EA
    trade.LogLevel(LOG_LEVEL_ALL); // Nível de log
    trade.SetAsyncMode(false); // Modo síncrono para garantir execução correta
    
    if((DailyResult(MagicNumber) + OpenResult(MagicNumber)) <= 0.95*iDailyTarget) {
        LiberarLockMeta();
        LiberarLockLoss();
        LiberarLockDrawdown();
    }
    

   calculaVolume();

   
   if (iPanel) {
        int _font_size = TerminalInfoInteger(TERMINAL_SCREEN_DPI) == 144 ? 9 : 12;
        MyPanel.Create(0, StringFormat("%s %s", MQLInfoString(MQL_PROGRAM_NAME), MVersion), 0, 50, 60, 330, 400, _font_size);
        MyPanel.CreateItem("status", "Status:", 0);
        MyPanel.CreateItem("ropen", "Res. Aberto:", 1);
        MyPanel.CreateItem("rdia",  "Res. Dia:", 2);
        MyPanel.CreateItem("rweek", "Res. Semana:", 3); 
        MyPanel.CreateItem("iMagicNumber", "MagicNumber:", 4);
        MyPanel.CreateItem("baseLine", "Base Line:", 5);
        
        // Adiciona informações do VWAP se ativado
        if(usarFiltroVWAP == sim) {
            MyPanel.CreateItem("vwapInfo", "VWAP Info:", 6);
            MyPanel.CreateItem("vwapStatus", "VWAP Status:", 7);
        }
                       
        
        MyPanel.UpdateItem("status", "inicializando..");
        MyPanel.UpdateItem("ropen", DoubleToString(OpenResult(MagicNumber), 2));
        MyPanel.UpdateItem("rdia", DoubleToString(DailyResult(MagicNumber), 2));
        MyPanel.UpdateItem("rweek", DoubleToString(weeklyResult(MagicNumber), 2));
        MyPanel.UpdateItem("iMagicNumber", (string)MagicNumber);
        
        // Atualiza informações do VWAP
        if(usarFiltroVWAP == sim) {
            double vwap = ObterVWAPAtual(timeframeVWAP, candlesVWAP);
            if(vwap > 0) {
                MyPanel.UpdateItem("vwapInfo", "VWAP: " + DoubleToString(vwap, _Digits));
                MyPanel.UpdateItem("vwapStatus", "Timeframe: " + EnumToString(timeframeVWAP));
            }
        }
        
        MyPanel.Run();
        ChartRedraw(0);
    }
    EventSetTimer(5); //Habilitando o timer do MQL5 para rodar a cada 5 segundos

    LogMsg(StringFormat("[%d] Inicializado com sucesso!", MagicNumber), LOG_LEVEL_INFO);
    // No início do OnInit, sincronizar a flag com o estado real
    posicaoAberta = has_open_position(MagicNumber);
    
    // Inicializa array VWAP
    if(usarFiltroVWAP == sim) {
        ArraySetAsSeries(ratesVWAP, true);
        ArrayResize(ratesVWAP, candlesVWAP);
        LogMsg("INFO: Array VWAP inicializado - Tamanho: " + IntegerToString(candlesVWAP), LOG_LEVEL_INFO);
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
    
    // Limpar todos os objetos, incluindo triggers
    ObjectsDeleteAll(0, prefixoObjeto);
    ChartRedraw(0);
    //Volume = 0;
    ArrayFree(rates);
    ArrayFree(niveis);
    ArrayFree(niveisSaidas);
    ArrayResize(linhasPreco,0);
    
    // Limpa array VWAP
    ArrayFree(ratesVWAP);
    
    if (iPanel)
        MyPanel.Destroy(reason);
        
    EventKillTimer();
    
    LogMsg("EA finalizado. Motivo: " + IntegerToString(reason), LOG_LEVEL_INFO);
}

void OnTimer() {
     
     int pos_proces = count_pos_process();
     int numTotal  = ArraySize(niveisSaidasHEDGING.confSaidasHEDGING);
     
     if (!breakevenAtivado && (numTotal-pos_proces) == posbreakeven ){
         
         LogMsg("HasOrders(MagicNumber) "+(string) HasOrders(MagicNumber),LOG_LEVEL_INFO);
         LogMsg("precoEntrada "+(string) precoEntrada,LOG_LEVEL_INFO);
         
         if (IsBought(MagicNumber) ) {
           LogMsg("Ativar IsBought ",LOG_LEVEL_DEBUG);            
           double newSl =   precoEntrada - (2* tickSize);  
           changePositionsSL(trade, MagicNumber, roundPriceH9K(newSl,tickSize));
            MyPanel.UpdateItem("status", "feita protecao");        
             ChartRedraw(0);
           
         } else if (IsSold(MagicNumber) ) {
           LogMsg("Ativar IsSold ",LOG_LEVEL_DEBUG);           
           double newSl = precoEntrada + (2* tickSize);
           changePositionsSL(trade, MagicNumber, newSl );
           MyPanel.UpdateItem("status", "feita protecao");  
            ChartRedraw(0);              
         }
      
         breakevenAtivado = true;
     }
      if (iPanel) {
        MyPanel.UpdateItem("ropen", DoubleToString(OpenResult(MagicNumber), 2));
        MyPanel.UpdateItem("rdia", DoubleToString(DailyResult(MagicNumber), 2));
        MyPanel.UpdateItem("rweek", DoubleToString(weeklyResult(MagicNumber), 2));
        
        // Atualiza informações do VWAP
        if(usarFiltroVWAP == sim) {
            double vwap = ObterVWAPAtual(timeframeVWAP, candlesVWAP);
            if(vwap > 0) {
                MyPanel.UpdateItem("vwapInfo", "VWAP: " + DoubleToString(vwap, _Digits));
                
                // Mostra status baseado na posição do preço atual
                double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                ENUM_POSICAO_VWAP posicaoVWAP = VerificarPosicaoVWAP(precoAtual, vwap, toleranciaVWAP);
                string statusVWAP = "";
                
                switch(posicaoVWAP) {
                    case VWAP_BULLISH: statusVWAP = "BULLISH (acima)"; break;
                    case VWAP_BEARISH: statusVWAP = "BEARISH (abaixo)"; break;
                    case VWAP_NEUTRO: statusVWAP = "NEUTRO (próximo)"; break;
                }
                
                MyPanel.UpdateItem("vwapStatus", "Status: " + statusVWAP);
            }
        }
        
        ChartRedraw(0);
    }
    
    // Atualizar e desenhar VWAP
    if(usarFiltroVWAP == sim) {
        DesenharVWAP();
    }
    
    if (vPauseEA) {
        if (iPanel) {
            MyPanel.UpdateItem("status", "pausado");
            ChartRedraw(0);
        }
        return;
    }
   
    
     
     
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick(){
    // Sincroniza a flag com o status real da corretora
    if (isNewBar(Periodo)){
       posicaoAberta = has_open_position(MagicNumber);
    }
    
    
    // Novo: verifica se mudou o dia e recarrega config se necessário
    datetime diaAtual = iTime(_Symbol, PERIOD_D1, 0);
    int nivelSelecionado = (int)NivelAtivo;
    int nivelIndex = nivelSelecionado - 1;
    if (diaAtual != ultimoDiaConfig) {
         caculaLinhasJust();
         CriarLinhasNivel();
         ChartRedraw(0);
         LogMsg("Configuração do canal recarregada para o novo dia.", LOG_LEVEL_DEBUG);
         
        
    }
   
   if (!i24h && !allowed_by_hour(iHoraIni, iHoraFim) ) {
        closeAllPositions(trade, MagicNumber);
        closeAllOpenOrders(trade, MagicNumber);        
        LiberarLockMeta();
        LiberarLockLoss();
        LiberarLockDrawdown();
        vDDTriggerActive = false;
        ArrayResize(linhasPreco,0);
         
        
        //PrintEstatisticasRobo();
        return;
    }
   
    // Obter dados do último candle
    if(CopyRates(_Symbol, Periodo, 0, 2, rates) <= 0)
    {
        LogMsg("ERRO: Falha ao copiar dados do último candle", LOG_LEVEL_ERROR);
        return;
    }
    ArraySetAsSeries(rates, true);
   
   if (riskManagement == sim){
         GerenciarRisk();
   }   
   
    
    
    if(AtivarInterval == sim){
      if(EstaNoHorarioDePausa(iHoraInterval1,iHoraInterval2)){
         if (isNewBar(Periodo)) {
            LogMsg("INFO: Hora de intervalo ativada ", LOG_LEVEL_INFO);
            PrintEstatisticasRobo();
         }
         return;
      }  
    }
   
   // No OnTick, só chama VerificarGatilhos 
     
    VerificarGatilhos(linhasPreco);
    
    // Atualizar e desenhar VWAP
    if(usarFiltroVWAP == sim) {
        DesenharVWAP();
    }
    
    // Cancela ordens pendentes de parciais se não houver mais posição aberta
    if (!posicaoAberta) {
        CancelarOrdensParciais();
        breakevenAtivado = false;
        niveisSaidasHEDGING.numeroTicket = 0;
    
    }else{
         posicaonaOrdensSaidasHeedgin(niveisSaidasHEDGING);
    }
}


void posicaonaOrdensSaidasHeedgin(ConfNivelSaidasHEDGING &array){

   if(!PositionSelectByTicket(array.numeroTicket)) {
       return;     
    }
   
  
   
   double priceAtual;
   if(array.posType == POSITION_TYPE_BUY) {
        priceAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   } else {
       priceAtual = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
  
   
   
   for(int i =  0 ; ArraySize(array.confSaidasHEDGING)-1 >=i ; i++) {
      if (array.confSaidasHEDGING[i].processada){
         continue;
      }
   
      if(array.posType == POSITION_TYPE_BUY && priceAtual >= array.confSaidasHEDGING[i].valorSaida) {
         bool order_sent =  trade.PositionClosePartial(array.numeroTicket,array.confSaidasHEDGING[i].qtdContratos,DesvioMaximoPontos);
         uint retcode = trade.ResultRetcode();
         if(!order_sent || retcode != TRADE_RETCODE_DONE ) {
            LogMsg("ERRO ao executar ordem de COMPRA: Retcode " + IntegerToString(retcode), LOG_LEVEL_ERROR);
            LogMsg("ERRO ao executar ordem de COMPRA: order_sent " + (string)order_sent, LOG_LEVEL_ERROR);
           continue ;
          }
       
        niveisSaidasHEDGING.confSaidasHEDGING[i].processada = true;
        LogMsg("INFO: Fechamento parcial executada -   Valor: " + DoubleToString(array.confSaidasHEDGING[i].valorSaida, 2)+
                                                     " Volume: "  +   DoubleToString(array.confSaidasHEDGING[i].qtdContratos,2)      , LOG_LEVEL_INFO);
       
        
        continue;
       } else if(array.posType == POSITION_TYPE_SELL && priceAtual <= array.confSaidasHEDGING[i].valorSaida) {
         bool order_sent =  trade.PositionClosePartial(array.numeroTicket,array.confSaidasHEDGING[i].qtdContratos,DesvioMaximoPontos);
         uint retcode = trade.ResultRetcode();
        if(!order_sent || retcode != TRADE_RETCODE_DONE ) {
            LogMsg("ERRO ao executar ordem de COMPRA: Retcode " + IntegerToString(retcode), LOG_LEVEL_ERROR);
            LogMsg("ERRO ao executar ordem de COMPRA: order_sent " + (string)order_sent, LOG_LEVEL_ERROR);
           continue ;
          }
         LogMsg("INFO: Fechamento parcial executada -  Valor: " + DoubleToString(array.confSaidasHEDGING[i].valorSaida, 2)+
                                                     " Volume: "  +   DoubleToString(array.confSaidasHEDGING[i].qtdContratos,2)      , LOG_LEVEL_INFO);
        
         niveisSaidasHEDGING.confSaidasHEDGING[i].processada = true;
         continue;
       } 
        
   }
      
     

}


//+------------------------------------------------------------------+
//| Calcula Take Profits múltiplos inteligentes                       |
//+------------------------------------------------------------------+
void CalcularTPsMultiplos(double precoEntrada, double stopLoss, double atr, double incremento, ENUM_POSITION_TYPE tipo, TakeProfitMultiplo &tps[])
{
    
    
    ArrayResize(tps, 4);
    
    // TP1: Próximo nível de canal (mais conservador)
    if(tipo == POSITION_TYPE_BUY) {
        tps[0].preco = precoEntrada + (incremento * 0.8); // 80% do incremento
        tps[1].preco = precoEntrada + (atr * tpATRMultiplier);
        tps[2].preco = precoEntrada + (MathAbs(precoEntrada - stopLoss) * tpRiskReward);
        tps[3].preco = precoEntrada + (atr * tpLongoMultiplier); // Alvo muito longo
    } else {
        tps[0].preco = precoEntrada - (incremento * 0.8);
        tps[1].preco = precoEntrada - (atr * tpATRMultiplier);
        tps[2].preco = precoEntrada - (MathAbs(stopLoss - precoEntrada) * tpRiskReward);
        tps[3].preco = precoEntrada - (atr * tpLongoMultiplier); // Alvo muito longo
    }
    
    // Configura percentuais e descrições
    tps[0].percentual = tpPercentual1;
    tps[1].percentual = tpPercentual2;
    tps[2].percentual = tpPercentual3;
    tps[3].percentual = tpPercentual4;
    
    tps[0].descricao = "TP1 - Canal";
    tps[1].descricao = "TP2 - ATR";
    tps[2].descricao = "TP3 - R:R";
    tps[3].descricao = "TP4 - Longo";
    
    // Arredonda preços para respeitar tick size
    for(int i = 0; i < 4; i++) {
        tps[i].preco = roundPriceH9K(tps[i].preco, tickSize);
        tps[i].ativo = true;
    }
    
    LogMsg("DEBUG: TPs calculados - TP1: " + DoubleToString(tps[0].preco, _Digits) + 
            " | TP2: " + DoubleToString(tps[1].preco, _Digits) + 
            " | TP3: " + DoubleToString(tps[2].preco, _Digits) + 
            " | TP4: " + DoubleToString(tps[3].preco, _Digits), LOG_LEVEL_DEBUG);
}


void caculaLinhasJust(){
    
    double fechamentoDiaAnterior = iClose(_Symbol, PERIOD_D1, 1);
    
    // Validação do fechamento do dia anterior
    if(fechamentoDiaAnterior <= 0) {
        LogMsg("ERRO: Fechamento do dia anterior inválido: " + DoubleToString(fechamentoDiaAnterior, _Digits), LOG_LEVEL_ERROR);
        return;
    }
    
    LogMsg("INFO: Fechamento dia anterior: "+ DoubleToString(fechamentoDiaAnterior, _Digits), LOG_LEVEL_DEBUG);
    
    ArrayResize(linhasPreco, numeroLinhas);
    
    // === FÓRMULA HÍBRIDA INTELIGENTE ===
    
    // 1. ATR (Average True Range) - Volatilidade real do mercado
    double atrArray[];
    ArraySetAsSeries(atrArray, true);
    int atrHandle = iATR(_Symbol, PERIOD_D1, 14);
    if(atrHandle == INVALID_HANDLE) {
        LogMsg("ERRO: Falha ao criar handle do ATR", LOG_LEVEL_ERROR);
        return;
    }
    
    if(CopyBuffer(atrHandle, 0, 1, 1, atrArray) <= 0) {
        LogMsg("ERRO: Falha ao copiar dados do ATR", LOG_LEVEL_ERROR);
        return;
    }
    double atr = atrArray[0];
    
    // 2. Range do dia anterior (High - Low)
    double rangeDia = CalcularRangeSemanaPassada();
    
    // 3. Volatilidade relativa ao preço (percentual)
    double volatilidadeRelativa = fechamentoDiaAnterior * 0.001; // 0.1%
    
    // 4. Fórmula híbrida com pesos otimizados
    double incrementoBase = (atr * 0.08) + (rangeDia * 0.3) + (volatilidadeRelativa * 0.5);
    
    // Log detalhado para debug e otimização
    LogMsg("DEBUG: ATR (14): " + DoubleToString(atr, _Digits) + 
            " | Range Dia: " + DoubleToString(rangeDia, _Digits) + 
            " | Volatilidade Relativa: " + DoubleToString(volatilidadeRelativa, _Digits), LOG_LEVEL_DEBUG);
    
    LogMsg("DEBUG: Incremento Base Final: " + DoubleToString(incrementoBase, _Digits), LOG_LEVEL_DEBUG);
    
    if(iPanel)
        MyPanel.UpdateItem("baseLine", DoubleToString(fechamentoDiaAnterior, _Digits));
    
    // Distribui as linhas de forma equilibrada ao redor do fechamento do dia anterior
    int meio = numeroLinhas / 2;
    
    for(int i = 0; i < numeroLinhas; i++) {
        if(i < meio) {
            // Linhas de suporte (abaixo do fechamento)
            double precoCalculado = fechamentoDiaAnterior - (incrementoBase * (meio - i));
            linhasPreco[i] = roundPriceH9K(precoCalculado, tickSize);
        } else if(i == meio) {
            // Linha central (fechamento do dia anterior)
            linhasPreco[i] = roundPriceH9K(fechamentoDiaAnterior, tickSize);
        } else {
            // Linhas de resistência (acima do fechamento)
            double precoCalculado = fechamentoDiaAnterior + (incrementoBase * (i - meio));
            linhasPreco[i] = roundPriceH9K(precoCalculado, tickSize);
        }
    }
    
    LogMsg("INFO: " + IntegerToString(numeroLinhas) + " linhas calculadas com incremento base de " + DoubleToString(incrementoBase, _Digits), LOG_LEVEL_DEBUG);
}

int count_pos_process(){
   
   int count = 0;
   for(int i =  0 ; ArraySize(niveisSaidasHEDGING.confSaidasHEDGING)-1 >=i ; i++) {
      if (niveisSaidasHEDGING.confSaidasHEDGING[i].processada){
        count ++; 
      }

   }
   return count;

}
void GerenciarRisk(){
    double l_result = DailyResult(MagicNumber) + OpenResult(MagicNumber);
    if (l_result > vMaxProfit) vMaxProfit = l_result;
    if (isNewBar(Periodo)) { LogMsg(StringFormat("[%d] Result of day at moment (%.2f / %.2f).", MagicNumber, iDailyTarget, l_result), LOG_LEVEL_INFO); }

    // 1. Drawdown
    if(vTargetLockDrawdown) {
        if (!vTargetLockDrawdownLogDone) {
            LogMsg(StringFormat("[%d] Drawdown %.2f achieved (%.2f / %.2f).", MagicNumber, iDrawDown, vMaxProfit, l_result), LOG_LEVEL_INFO);
            closeAllOpenOrders(trade, MagicNumber);
            closeAllPositions(trade, MagicNumber);
            vTargetLockDrawdownLogDone = true;
        }
        return;
    }
    if(l_result >= iDDTrigger) {
        if(!vDDTriggerActive) LogMsg(StringFormat("[%d] Drawdown trigger activated (%.2f).", MagicNumber, l_result), LOG_LEVEL_INFO);
        vDDTriggerActive = true;
    }
    if(vDDTriggerActive && l_result <= (1 - iDrawDown/100)*vMaxProfit) {
        if (!vTargetLockDrawdownLogDone) {
            LogMsg(StringFormat("[%d] Drawdown %.2f achieved (%.2f / %.2f).", MagicNumber, iDrawDown, vMaxProfit, l_result), LOG_LEVEL_INFO);
            closeAllOpenOrders(trade, MagicNumber);
            closeAllPositions(trade, MagicNumber);
            vTargetLockDrawdownLogDone = true;
        }
        vTargetLockDrawdown = true;
        return;
    }

    // 2. Meta
    if(vTargetLockMeta) {
        if (!vTargetLockMetaLogDone) {
            LogMsg(StringFormat("[%d] DailyTarget achieved (%.2f / %.2f).", MagicNumber, iDailyTarget, l_result), LOG_LEVEL_INFO);
            closeAllOpenOrders(trade, MagicNumber);
            closeAllPositions(trade, MagicNumber);
            vTargetLockMetaLogDone = true;
        }
        return;
    }
    if(l_result >= iDailyTarget) {
        if (!vTargetLockMetaLogDone) {
            LogMsg(StringFormat("[%d] DailyTarget achieved (%.2f / %.2f).", MagicNumber, iDailyTarget, l_result), LOG_LEVEL_INFO);
            closeAllOpenOrders(trade, MagicNumber);
            closeAllPositions(trade, MagicNumber);
            vTargetLockMetaLogDone = true;
        }
        vTargetLockMeta = true;
        return;
    }

    // 3. Loss
    if(vTargetLockLoss) {
        if (!vTargetLockLossLogDone) {
            LogMsg(StringFormat("[%d] LossTarge achieved  %.2f.", MagicNumber, iLossTarget), LOG_LEVEL_INFO);
            closeAllOpenOrders(trade, MagicNumber);
            closeAllPositions(trade, MagicNumber);
            vTargetLockLossLogDone = true;
        }
        return;
    }
    if((DailyResult(MagicNumber) + OpenResult(MagicNumber)) <= -1 * iLossTarget) {
        if (!vTargetLockLossLogDone) {
            LogMsg(StringFormat("[%d] LossTarge achieved  %.2f.", MagicNumber, iLossTarget), LOG_LEVEL_INFO);
            closeAllOpenOrders(trade, MagicNumber);
            closeAllPositions(trade, MagicNumber);
            vTargetLockLossLogDone = true;
        }
        vTargetLockLoss = true;
        return;
    }
}



//+------------------------------------------------------------------+
//| Calcula os níveis de preço das linhas para um nível específico    |
//+------------------------------------------------------------------+
void CalcularLinhasPreco(double &linhas[], NivelCanal &nivel)
{
    ArrayResize(linhas, numeroLinhas);
    
    for(int i = 0; i < numeroLinhas; i++)
    {
        linhas[i] = nivel.precoBase - (i * nivel.incrementoTick);
    }
}
//+------------------------------------------------------------------+
//| Calcula o volume das operacoes                                   |
//+------------------------------------------------------------------+
double calculaVolume(){
    
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    double volume  = 0.0;
    ParseStringToConfArray(iConfSaidas, niveisSaidas);
    // Mostrar os resultados
    for (int i = 0; i < ArraySize(niveisSaidas); i++) {
        LogMsg("Contrato: "+ (string)niveisSaidas[i].qtdContratos+ " | Percentual: "+ (string)niveisSaidas[i].percentSaida, LOG_LEVEL_INFO);
        volume = volume + niveisSaidas[i].qtdContratos;
    }
    
    double resultado = MathRound(volume / volumeStep) * volumeStep;
      
      // Garantir que não seja menor que o mínimo
      if(resultado < volumeMin)
         resultado = volumeMin;
         
    LogMsg("Total de Contrato: "+ DoubleToString(volume), LOG_LEVEL_INFO); 
    return volume;
}



//+------------------------------------------------------------------+
//| Cria as linhas horizontais para um nível específico               |
//+------------------------------------------------------------------+
void CriarLinhasNivel()
{
    
    //CalcularLinhasPreco(linhasPreco, nivel);
    
    datetime tempo = TimeCurrent();
    double pontoPip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    
    for(int i = 0; i < ArraySize(linhasPreco); i++)
    {
        string nomeObjeto = prefixoObjeto + "Nivel_1" + IntegerToString(i);
        
        if(!ObjectCreate(0, nomeObjeto, OBJ_HLINE, 0, 0, linhasPreco[i]))
        {
            LogMsg("ERRO: Falha ao criar linha " + nomeObjeto, LOG_LEVEL_ERROR);
            continue;
        }
        
        ObjectSetInteger(0, nomeObjeto, OBJPROP_COLOR, ColorBrighten(clrAliceBlue, 20 * i));
        ObjectSetInteger(0, nomeObjeto, OBJPROP_STYLE, EstiloLinha);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_WIDTH, EspessuraLinha);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_BACK, true);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_HIDDEN, true);
        
        if(MostrarPreco == sim)
        {
            string nomeTexto = prefixoObjeto + "Nivel_1" + "txt_" + IntegerToString(i);
            double precoTexto = linhasPreco[i] + (20 * pontoPip);
            
            if(!ObjectCreate(0, nomeTexto, OBJ_TEXT, 0, tempo, precoTexto))
            {
                LogMsg("ERRO: Falha ao criar texto " + nomeTexto, LOG_LEVEL_ERROR);
                continue;
            }
            
            ObjectSetString(0, nomeTexto, OBJPROP_TEXT, "Nivel_1" + DoubleToString(linhasPreco[i], _Digits));
            ObjectSetInteger(0, nomeTexto, OBJPROP_COLOR, ColorBrighten(clrAliceBlue, 20 * i));
            ObjectSetInteger(0, nomeTexto, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
            ObjectSetInteger(0, nomeTexto, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, nomeTexto, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, nomeTexto, OBJPROP_FONTSIZE, 10);
        }
        
        LogMsg("DEBUG: Linha criada - Nome: " + nomeObjeto + " Preço: " + DoubleToString(linhasPreco[i], _Digits), LOG_LEVEL_DEBUG);
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Atualiza as linhas de um nível específico                         |
//+------------------------------------------------------------------+
void AtualizarLinhasNivel(NivelCanal &nivel)
{
    datetime tempo = TimeCurrent();
    double pontoPip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    for(int i = 0; i < ArraySize(linhasPreco); i++)
    {
        string nomeObjeto = prefixoObjeto + nivel.prefixo + IntegerToString(i);
        
        if(ObjectFind(0, nomeObjeto) >= 0)
        {
            ObjectSetDouble(0, nomeObjeto, OBJPROP_PRICE, linhasPreco[i]);
            
            if(MostrarPreco == sim)
            {
                string nomeTexto = prefixoObjeto + nivel.prefixo + "txt_" + IntegerToString(i);
                double precoTexto = linhasPreco[i] + (20 * pontoPip);
                
                if(ObjectFind(0, nomeTexto) >= 0)
                {
                    ObjectSetDouble(0, nomeTexto, OBJPROP_PRICE, precoTexto);
                    ObjectSetString(0, nomeTexto, OBJPROP_TEXT, nivel.prefixo + DoubleToString(linhasPreco[i], _Digits));
                    ObjectSetInteger(0, nomeTexto, OBJPROP_TIME, tempo);
                }
                else
                {
                    if(ObjectCreate(0, nomeTexto, OBJ_TEXT, 0, tempo, precoTexto))
                    {
                        ObjectSetString(0, nomeTexto, OBJPROP_TEXT, nivel.prefixo + DoubleToString(linhasPreco[i], _Digits));
                        ObjectSetInteger(0, nomeTexto, OBJPROP_COLOR, ColorBrighten(nivel.corBase, 20 * i));
                        ObjectSetInteger(0, nomeTexto, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
                        ObjectSetInteger(0, nomeTexto, OBJPROP_SELECTABLE, false);
                        ObjectSetInteger(0, nomeTexto, OBJPROP_HIDDEN, true);
                        ObjectSetInteger(0, nomeTexto, OBJPROP_FONTSIZE, 10);
                    }
                }
            }
        }
        else
        {
            if(ObjectCreate(0, nomeObjeto, OBJ_HLINE, 0, 0, linhasPreco[i]))
            {
                ObjectSetInteger(0, nomeObjeto, OBJPROP_COLOR, ColorBrighten(nivel.corBase, 20 * i));
                ObjectSetInteger(0, nomeObjeto, OBJPROP_STYLE, EstiloLinha);
                ObjectSetInteger(0, nomeObjeto, OBJPROP_WIDTH, EspessuraLinha);
                ObjectSetInteger(0, nomeObjeto, OBJPROP_BACK, true);
                ObjectSetInteger(0, nomeObjeto, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, nomeObjeto, OBJPROP_HIDDEN, true);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Remove todos os objetos criados pelo EA                           |
//+------------------------------------------------------------------+
void LimparObjetos()
{
    int count = ObjectsDeleteAll(0, prefixoObjeto);
    
    // Limpa objetos VWAP específicos
    if(usarFiltroVWAP == sim) {
        LimparVWAP();
    }
    
    //LogMsg("Objetos removidos: " + IntegerToString(count), LOG_LEVEL_INFO);
}

//+------------------------------------------------------------------+
//| Função para clarear/escurecer uma cor                             |
//+------------------------------------------------------------------+
color ColorBrighten(color clr, int percent)
{
    int r = (clr >> 16) & 0xFF;
    int g = (clr >> 8) & 0xFF;
    int b = clr & 0xFF;
    
    r = MathMin(255, r + (percent * 255 / 100));
    g = MathMin(255, g + (percent * 255 / 100));
    b = MathMin(255, b + (percent * 255 / 100));
    
    return (color)((r << 16) + (g << 8) + b);
}



//+------------------------------------------------------------------+
//| Verifica gatilhos nos preços de abertura e fechamento             |
//+--------------------------------------------------------------+
void VerificarGatilhos(double &linhas[]){
    if(ArraySize(rates) < 2) {
        LogMsg("ERRO: Array rates não possui candles suficientes!", LOG_LEVEL_ERROR);
        return;
    }
    
    
    // Verificar se o candle atravessa alguma linha
    for(int i = 0; i < ArraySize(linhas); i++){
        // Verifica se o candle atravessou a linha (abertura abaixo e fechamento acima OU vice-versa)
        if((rates[1].open < linhas[i] && rates[1].close > linhas[i]) || 
           (rates[1].open > linhas[i] && rates[1].close < linhas[i])){
             rateGatilho = rates[1];
             nivelBase = linhas[i];
             LogMsg("INFO: Gatilho acionado: " +
                     "Linha: "+ DoubleToString(linhas[i])+
                     "Open: "+ DoubleToString(rates[1].open)+
                     "Close: "+ DoubleToString(rates[1].close), LOG_LEVEL_DEBUG); 
            if (iPanel)
                  MyPanel.UpdateItem("status", "gatilho acionado");          
                     
            VerificarEntradas(linhas, i);
            break;
        };
    }
}

//+------------------------------------------------------------------+
//| Verifica e executa entradas                                        |
//+------------------------------------------------------------------+
void VerificarEntradas(double &linhas[], int indice_linha){
    if(indice_linha < 0 || indice_linha >= ArraySize(linhas)) {
        LogMsg("ERRO: indice_linha fora do range do array de linhas!", LOG_LEVEL_ERROR);
        return;
    }
    // Bloqueio por locks de risco
    if (vTargetLockMeta || vTargetLockLoss || vTargetLockDrawdown) {
        LogMsg("ENTRADA BLOQUEADA: Algum lock de risco está ativo (Meta, Loss ou Drawdown)", LOG_LEVEL_DEBUG);
        return;
    }
    if (posicaoAberta) {
        LogMsg("ENTRADA BLOQUEADA: Existem posicaoes abertas", LOG_LEVEL_DEBUG);
        return;
    }
    
    double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    LogMsg("DEBUG: StopLevel exigido pelo ativo: " + DoubleToString(stopLevel, _Digits), LOG_LEVEL_DEBUG);
    LogMsg("DEBUG: TickSize do ativo: " + DoubleToString(tickSize, _Digits), LOG_LEVEL_DEBUG);
    double incremento = MathAbs(linhas[indice_linha]-linhas[indice_linha+1]); //MathAbs(rateGatilho.close-rateGatilho.low); 
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
    // Compra: fechamento acima da linha -> EXECUTA COMPRA
    if(rates[0].close > linhas[indice_linha] 
       && rateGatilho.high < SymbolInfoDouble(_Symbol, SYMBOL_BID) ){
        
        // Aplicar filtro VWAP antes de executar COMPRA
        if(usarFiltroVWAP == sim) {
            if(!AplicarFiltroVWAP(SymbolInfoDouble(_Symbol, SYMBOL_BID), timeframeVWAP, candlesVWAP, toleranciaVWAP,POSITION_TYPE_BUY)) {
                LogMsg("INFO: COMPRA bloqueada pelo filtro VWAP", LOG_LEVEL_INFO);
                return; // Bloqueia entrada
            }
        }
        
          // Calcula TPs múltiplos
         TakeProfitMultiplo tpsCompra[];
         // Usa ATR já calculado na função caculaLinhasJust()
         double atr = 0;
         int atrHandle = iATR(_Symbol, PERIOD_D1, 14);
         if(atrHandle != INVALID_HANDLE) {
             double atrArray[];
             ArraySetAsSeries(atrArray, true);
             if(CopyBuffer(atrHandle, 0, 1, 1, atrArray) > 0) {
                 atr = atrArray[0];
             }
         }
         CalcularTPsMultiplos(SymbolInfoDouble(_Symbol, SYMBOL_BID), 0, atr, incremento, POSITION_TYPE_BUY, tpsCompra);
         
         double takeProfit = tpsCompra[0].preco; // Usa TP1 como referência para validação
         if(takeProfit > 0){
             precoEntrada = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double stop_calc = linhas[indice_linha] - (incremento * (percentualStopLoss/100.0));
            double minDist = MathMax(stopLevel, tickSize * 2);
            double stop_loss = MathMin(roundPriceH9K(stop_calc, tickSize), precoEntrada - tickSize);
            if (stop_loss >= precoEntrada) stop_loss = precoEntrada - tickSize;
            if ((precoEntrada - stop_loss) < minDist)
                stop_loss = precoEntrada - minDist;
            
            // Valida se pelo menos o TP1 é válido
            if(stop_loss < precoEntrada && takeProfit > precoEntrada &&
               (precoEntrada - stop_loss > stopLevel) && (takeProfit - precoEntrada > stopLevel)) {
                
                if (ExecutarCompra(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), 0)) {
                    ultimoCandleEntrada = rateGatilho.time;
                    canalEntradaIndex = indice_linha;
                    posicaoTicket = trade.ResultOrder();
                    
                    // Cria ordens para TPs múltiplos
                    if(false) {
                       // CriarOrdensTPMultiplo(tpsCompra, precoEntrada, stop_loss, POSITION_TYPE_BUY);
                    } else {
                        // Sistema antigo de parciais
                        for (int i = 0; i < ArraySize(niveisSaidas); i++) {
                            double tp = roundPriceH9K(precoEntrada,tickSize) + (incremento * (niveisSaidas[i].percentSaida/100.0));
                            double vol = MathMax(NormalizeDouble(MathRound(niveisSaidas[i].qtdContratos / volumeStep) * volumeStep, 2), minVolume); 
                            if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING){
                                trade.SellLimit(vol, roundPriceH9K(tp, tickSize), _Symbol, 0, 0, ORDER_TIME_GTC, 0, "Parcial "+ (string)(i+1) );
                            }else if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){
                                niveisSaidasHEDGING.numeroTicket = posicaoTicket;
                                niveisSaidasHEDGING.posType = POSITION_TYPE_BUY;
                                int tamanho = ArraySize(niveisSaidasHEDGING.confSaidasHEDGING);
                                ArrayResize(niveisSaidasHEDGING.confSaidasHEDGING, tamanho + 1);
                                if (tpMultiplo){
                                 niveisSaidasHEDGING.confSaidasHEDGING[tamanho].qtdContratos =tpsCompra[tamanho].volume;
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].valorSaida = tpsCompra[tamanho].preco;
                                }else {
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].qtdContratos =vol;
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].valorSaida = tp;
                                }
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].processada = false;
                                
                            }
                        }
                    }
                }
            } else {
                LogMsg("ERRO: Preços inválidos para COMPRA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits) +
                       " (verifique se SL/TP respeitam o stop level mínimo: " + DoubleToString(stopLevel, _Digits) + ")", LOG_LEVEL_ERROR);
            }
        }
    }
    // Venda: fechamento abaixo da linha -> EXECUTA VENDA
    else if( rates[0].close < linhas[indice_linha] 
          && rateGatilho.low > SymbolInfoDouble(_Symbol, SYMBOL_ASK)  ){ 
        
        // Aplicar filtro VWAP antes de executar VENDA
        if(usarFiltroVWAP == sim) {
            if(!AplicarFiltroVWAP(SymbolInfoDouble(_Symbol, SYMBOL_ASK), timeframeVWAP, candlesVWAP, toleranciaVWAP,POSITION_TYPE_SELL)) {
                LogMsg("INFO: VENDA bloqueada pelo filtro VWAP", LOG_LEVEL_INFO);
                return; // Bloqueia entrada
            }
        }
        
                  // Calcula TPs múltiplos
         TakeProfitMultiplo tpsVenda[];
         // Usa ATR já calculado na função caculaLinhasJust()
         double atr = 0;
         int atrHandle = iATR(_Symbol, PERIOD_D1, 14);
         if(atrHandle != INVALID_HANDLE) {
             double atrArray[];
             ArraySetAsSeries(atrArray, true);
             if(CopyBuffer(atrHandle, 0, 1, 1, atrArray) > 0) {
                 atr = atrArray[0];
             }
         }
         CalcularTPsMultiplos(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, atr, incremento, POSITION_TYPE_SELL, tpsVenda);
         
         double takeProfit = tpsVenda[0].preco; // Usa TP1 como referência para validação
         if(takeProfit > 0){
             precoEntrada = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double stop_calc = linhas[indice_linha] + (incremento * (percentualStopLoss/100.0));
            double minDist = MathMax(stopLevel, tickSize * 2);
            double stop_loss = MathMax(roundPriceH9K(stop_calc, tickSize), precoEntrada + tickSize);
            if (stop_loss <= precoEntrada) stop_loss = precoEntrada + tickSize;
            if ((stop_loss - precoEntrada) < minDist)
                stop_loss = precoEntrada + minDist;
            
            // Valida se pelo menos o TP1 é válido
            if(stop_loss > precoEntrada && takeProfit < precoEntrada &&
               (stop_loss - precoEntrada > stopLevel) && (precoEntrada - takeProfit > stopLevel)) {
                
                if (ExecutarVenda(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), 0)) {
                    ultimoCandleEntrada = rateGatilho.time;
                    canalEntradaIndex = indice_linha;
                    posicaoTicket = trade.ResultOrder();
                    
                    // Cria ordens para TPs múltiplos
                    if(false) {
                        //CriarOrdensTPMultiplo(tpsVenda, precoEntrada, stop_loss, POSITION_TYPE_SELL);
                    } else {
                        // Sistema antigo de parciais
                        for (int i = 0; i < ArraySize(niveisSaidas); i++) {
                            double tp = roundPriceH9K(precoEntrada,tickSize) - (incremento * (niveisSaidas[i].percentSaida/100.0));
                            double vol = MathMax(NormalizeDouble(MathRound(niveisSaidas[i].qtdContratos / volumeStep) * volumeStep, 2), minVolume);
                            if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING){
                                trade.BuyLimit(vol, roundPriceH9K(tp, tickSize), _Symbol, 0, 0, ORDER_TIME_GTC, 0, "Parcial "+ (string)(i+1) );
                            }else if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){
                                niveisSaidasHEDGING.numeroTicket = posicaoTicket;
                                niveisSaidasHEDGING.posType = POSITION_TYPE_SELL;
                                int tamanho = ArraySize(niveisSaidasHEDGING.confSaidasHEDGING);
                                ArrayResize(niveisSaidasHEDGING.confSaidasHEDGING, tamanho + 1);
                                if (tpMultiplo){
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].qtdContratos =tpsVenda[tamanho].volume;
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].valorSaida = tpsVenda[tamanho].preco;
                                }else {
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].qtdContratos =vol;
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].valorSaida = tp;
                                }
                                niveisSaidasHEDGING.confSaidasHEDGING[tamanho].processada = false;
                            }
                        }
                    }
                }
            } else {
                LogMsg("ERRO: Preços inválidos para VENDA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits) +
                       " (verifique se SL/TP respeitam o stop level mínimo: " + DoubleToString(stopLevel, _Digits) + ")", LOG_LEVEL_ERROR);
            }
        }
    }
    
  
}


//+------------------------------------------------------------------+
//| Executa ordem de compra                                            |
//+------------------------------------------------------------------+
bool ExecutarCompra(double preco_entrada, double stop_loss, double take_profit){
    
    double volume = calculaVolume();
    bool order_sent = trade.Buy(volume, _Symbol, preco_entrada, stop_loss, take_profit, MQLInfoString(MQL_PROGRAM_NAME) + " : " + _Symbol);
    uint retcode = trade.ResultRetcode();
    if(!order_sent || retcode != TRADE_RETCODE_DONE) {
        LogMsg("ERRO ao executar ordem de COMPRA: Retcode " + IntegerToString(retcode), LOG_LEVEL_ERROR);
        return false;
    }
    LogMsg("INFO: Ordem de COMPRA executada - Volume: " + DoubleToString(volume, 2) +
           " PE: " + DoubleToString(preco_entrada, _Digits) +
           " SL: " + DoubleToString(stop_loss, _Digits) +
           " TP: " + DoubleToString(take_profit, _Digits), LOG_LEVEL_INFO);
    posicaoAberta = true;
    return order_sent;
}

//+------------------------------------------------------------------+
//| Executa ordem de venda                                            |
//+------------------------------------------------------------------+
bool ExecutarVenda(double preco_entrada, double stop_loss, double take_profit){
    double volume  = calculaVolume();
    bool order_sent = trade.Sell(volume, _Symbol, preco_entrada, stop_loss, take_profit, MQLInfoString(MQL_PROGRAM_NAME) +  " : " + _Symbol);
    uint retcode = trade.ResultRetcode();
    if(!order_sent || retcode != TRADE_RETCODE_DONE) {
        LogMsg("ERRO ao executar ordem de VENDA: Retcode " + IntegerToString(retcode), LOG_LEVEL_ERROR);
        return false;
    }
    LogMsg("INFO: Ordem de VENDA executada - Volume: " + DoubleToString(volume, 2) +
           " PE: " + DoubleToString(preco_entrada, _Digits) +
           " SL: " + DoubleToString(stop_loss, _Digits) +
           " TP: " + DoubleToString(take_profit, _Digits), LOG_LEVEL_INFO);
    posicaoAberta = true;
    return order_sent;
}


bool waitForOrderExecution(double amount, ulong magicNumber) {
    // Timeout settings
    const int MAX_WAIT_TIME_MS = 5000; // 5 seconds
    const int SLEEP_TIME_MS = 100;
    int elapsed_time = 0;
    
    while(!has_order_at(amount, magicNumber, 0)) {
        Sleep(SLEEP_TIME_MS);
        elapsed_time += SLEEP_TIME_MS;
        
        if(elapsed_time >= MAX_WAIT_TIME_MS || HasPosition(magicNumber) <= 0) {
            return false;
        }
    }
    
    return true;
}


//+------------------------------------------------------------------+
//| Encontra próximo nível superior                                    |
//+------------------------------------------------------------------+
double EncontrarProximoNivelSuperior(double &linhas[], int indice_atual, double preco_ref)
{
    for(uint j = (indice_atual > 0 ? (uint)(indice_atual - 1) : 0); j < ArraySize(linhas); j++)
    {
        if(linhas[j] > preco_ref)
            return linhas[j];
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Encontra próximo nível inferior                                    |
//+------------------------------------------------------------------+
double EncontrarProximoNivelInferior(double &linhas[], int indice_atual, double preco_ref)
{
    int size = (int)ArraySize(linhas);
    for(int j = indice_atual + 1; j >= 0 && j < size; j--)
    {
        if(linhas[j] < preco_ref)
            return linhas[j];
    }
    return 0;
}

bool EstaNoHorarioDePausa(string horaInicio, string horaFim)
{
    // Obter o horário atual
    MqlDateTime agora;
    TimeToStruct(TimeCurrent(), agora);
    
    // Converter strings de horário para minutos desde meia-noite
    int minutosInicio = ConverterHorarioParaMinutos(horaInicio);
    int minutosFim = ConverterHorarioParaMinutos(horaFim);
    int minutosAtual = agora.hour * 60 + agora.min;
    
    // Verificar se o horário atual está no intervalo de pausa
    if (minutosInicio <= minutosFim)
    {
        // Caso normal: início e fim no mesmo dia
        return (minutosAtual >= minutosInicio && minutosAtual <= minutosFim);
    }
    else
    {
        // Caso especial: intervalo cruza meia-noite (ex: 22:00 até 02:00)
        return (minutosAtual >= minutosInicio || minutosAtual <= minutosFim);
    }
}
int ConverterHorarioParaMinutos(string horario)
{
    string partes[];
    int numPartes = StringSplit(horario, ':', partes);
    if (numPartes < 2) {
        LogMsg("Erro: Formato de horário inválido. Use HH:MM ou HH:MM:SS", LOG_LEVEL_ERROR);
        return -1;
    }
    int horas = (int)StringToInteger(partes[0]);
    int minutos = (int)StringToInteger(partes[1]);
    // Validar valores
    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59) {
        LogMsg("Erro: Horário inválido. Horas: 0-23, Minutos: 0-59", LOG_LEVEL_ERROR);
        return -1;
    }
    // Aceita segundos, mas ignora
    return horas * 60 + minutos;
}


// Retorna true se houver posição aberta para o símbolo e MagicNumber
bool has_open_position(ulong magic) {
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            LogMsg("DEBUG: Ticket encontrado: " + IntegerToString(ticket) +
                   " Symbol: " + PositionGetString(POSITION_SYMBOL) +
                   " Magic: " + IntegerToString(PositionGetInteger(POSITION_MAGIC)), LOG_LEVEL_DEBUG);
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic) {
                return true;
            }
        }
    }
    return false;
}

// Retorna true se houver ordem pendente para o símbolo e MagicNumber
bool has_open_order(ulong magic) {
    for(int i = 0; i < OrdersTotal(); i++) {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket)) {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
               OrderGetInteger(ORDER_MAGIC) == magic &&
               (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT ||
                OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT ||
                OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP ||
                OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)) {
                return true;
            }
        }
    }
    return false;
}

// Funções utilitárias para liberar locks
void LiberarLockMeta() {
    vTargetLockMeta = false;
    vTargetLockMetaLogDone = false;
}
void LiberarLockLoss() {
    vTargetLockLoss = false;
    vTargetLockLossLogDone = false;
}
void LiberarLockDrawdown() {
    vTargetLockDrawdown = false;
    vTargetLockDrawdownLogDone = false;
}


//+------------------------------------------------------------------+
//| Função para atualizar estatísticas de operações do dia           |
//+------------------------------------------------------------------+
void AtualizarEstatisticasOperacoes() {
    qtdOperacoes = 0;
    qtdGain = 0;
    qtdLoss = 0;
    datetime diaInicio = iTime(_Symbol, PERIOD_D1, 0); // início do dia atual
    ulong ticket;
    double profit;
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ticket = HistoryDealGetTicket(i);
        if(HistoryDealSelect(ticket)) {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol) {
                datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                if(closeTime >= diaInicio) {
                    long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
                    if(entryType == (long)DEAL_ENTRY_OUT || entryType == (long)DEAL_ENTRY_INOUT) { // saída de posição
                        qtdOperacoes++;
                        profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                        if(profit > 0.0)
                            qtdGain++;
                        else if(profit < 0.0)
                            qtdLoss++;
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do robô                                     |
//+------------------------------------------------------------------+
void PrintEstatisticasRobo() {
    AtualizarEstatisticasOperacoes();
    double lucroDia = DailyResult(MagicNumber);
    double lucroAberto = OpenResult(MagicNumber);
    int numPosicoes = HasPosition(MagicNumber);
    int numOrdens = OpenOrdersCount(MagicNumber);
    string locks = "Meta: " + (vTargetLockMeta ? "ON" : "OFF") + ", Loss: " + (vTargetLockLoss ? "ON" : "OFF") + ", Drawdown: " + (vTargetLockDrawdown ? "ON" : "OFF");
    
    LogMsg("===== ESTATÍSTICAS DO ROBÔ =====", LOG_LEVEL_INFO);
    LogMsg("Lucro do dia: " + DoubleToString(lucroDia, 2), LOG_LEVEL_INFO);
    LogMsg("Lucro aberto: " + DoubleToString(lucroAberto, 2), LOG_LEVEL_INFO);
    LogMsg("Lucro máximo do dia: " + DoubleToString(vMaxProfit, 2), LOG_LEVEL_INFO);
    LogMsg("Posições abertas: " + IntegerToString(numPosicoes), LOG_LEVEL_INFO);
    LogMsg("Ordens pendentes: " + IntegerToString(numOrdens), LOG_LEVEL_INFO);
    LogMsg("Qtd operações fechadas: " + IntegerToString(qtdOperacoes), LOG_LEVEL_INFO);
    LogMsg("Qtd GAIN: " + IntegerToString(qtdGain), LOG_LEVEL_INFO);
    LogMsg("Qtd LOSS: " + IntegerToString(qtdLoss), LOG_LEVEL_INFO);
    LogMsg("Locks: " + locks, LOG_LEVEL_INFO);
    LogMsg("Target diário: " + DoubleToString(iDailyTarget, 2) + ", Loss diário: " + DoubleToString(iLossTarget, 2) + ", Drawdown: " + DoubleToString(iDrawDown, 2) + "%", LOG_LEVEL_INFO);
    LogMsg("=================================", LOG_LEVEL_INFO);
}

// Função pública para chamada manual
void PrintEstatisticasRoboManual() {
    PrintEstatisticasRobo();
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
        if (m_deal.Magic() == MagicNumber) {
            if((ENUM_DEAL_REASON)reason==DEAL_REASON_SL)
                Print("Stop Loss activation");
            else if((ENUM_DEAL_REASON)reason == DEAL_REASON_TP)
                vTPTrigger = true; //só libera para repor quando tem TP
        }
    }
    break;
    }
    // Após eventos de fechamento de posição
    AtualizarStatusPosicao();

    // Se não houver mais posição aberta, cancela ordens pendentes de parciais
    if (!posicaoAberta) {
        if (m_deal.Magic() == MagicNumber){
           CancelarOrdensParciais();
           breakevenAtivado = false;
           niveisSaidasHEDGING.numeroTicket = 0;
           ArrayResize(niveisSaidasHEDGING.confSaidasHEDGING,0);
            trailingStopAtivado = false;
            ultimoTrailingStop = 0.0;
            canalTrailingAtivado = -1;
           
           
           LogMsg("Limpando as variaveis", LOG_LEVEL_INFO);
        }
    }
}

// Ao fechar posição (em GerenciarBreakeven, GerenciarSaidasParciaisProgressivas, OnTradeTransaction, etc), setar posicaoAberta = false quando não houver mais posição
// Exemplo: após detectar que não há mais posição aberta
void AtualizarStatusPosicao() {
    posicaoAberta = has_open_position(MagicNumber);
    ordensAberta = has_open_order(MagicNumber);
    
}
// Chamar AtualizarStatusPosicao após eventos de fechamento de posição
//+------------------------------------------------------------------+
//| Função para log com nível                                        |
//+------------------------------------------------------------------+
void LogMsg(string mensagem, LOG_LEVEL nivel)
{
   if (MostrarLogs == sim && nivel <= LogLevel) {
    if (nivel == LOG_LEVEL_ERROR) {
        Alert(mensagem);
    } else if (nivel == LOG_LEVEL_INFO) {
           Print(mensagem);
    } else if (nivel == LOG_LEVEL_DEBUG) {
        Print(mensagem);
    }
}
}

//+------------------------------------------------------------------+
//| Função para calcular Magic Number único e consistente             |
//+------------------------------------------------------------------+
ulong CalcularMagicNumber(const string eaName, const string symbol) {
    string key = StringFormat("%s_%s_%s", eaName, symbol, InstanceName);
   
   // Inicializa o hash com uma constante não nula
   ulong hash = 5381;
   
   // Calcula o hash usando o algoritmo DJB2
   for(int i = 0; i < StringLen(key); i++)
   {
      hash = ((hash << 5) + hash) + (uchar)StringGetCharacter(key, i); // hash * 33 + c
   }
   
   // Garante que o número caiba em 9 dígitos e não seja zero
   hash = (hash % 999999999ULL) + 1; // Limite ajustado para 9 dígitos e evita zero
   
   return hash;
}

// Cancelar ordens limitadas pendentes ao fechar posição
double CancelarOrdensParciais() {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == MagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol)  {
               trade.OrderDelete(ticket);
            }
        }
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Função para converter string em array de ConfNivelSaidas         |
//+------------------------------------------------------------------+
void ParseStringToConfArray(string entrada, ConfNivelSaidas &resultArray[]) {
    // Divide por vírgulas
    string partes[];
    StringSplit(entrada, ',', partes);

    // Redimensiona array de structs
    ArrayResize(resultArray, ArraySize(partes));

    for (int i = 0; i < ArraySize(partes); i++) {
        string par[]; // [0] = qtdContratos, [1] = percentSaida
        StringSplit(partes[i], ':', par);

        if (ArraySize(par) == 2) {
            resultArray[i].qtdContratos = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) * (double)StringToInteger(par[0]);
            resultArray[i].percentSaida = (double)StringToInteger(par[1]);
        } else {
            Print("Erro ao interpretar: ", partes[i]);
        }
    }
}


int HasOrders(ulong l_magic)
{
    int total_orders = OrdersTotal();
    int open_orders = 0;
    
    for(int i = 0; i < total_orders; i++) 
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderSelect(ticket))  // Dupla verificação
        {
            if(OrderGetInteger(ORDER_MAGIC) == l_magic) 
            {
                open_orders++;
            }
        }
    }
    return open_orders;
}

//+------------------------------------------------------------------+
//| Create the "Button1" button                                      |
//+------------------------------------------------------------------+

bool CH9kPanel::CreateButton1() {
    int x1 = INDENT_LEFT;
    int y1 = INDENT_TOP + 170;
    int x2 = x1 + 250;
    int y2 = y1 + 50;

    if(!m_button1.Create(m_chart_id, m_name+"_Bt1", m_subwin, x1, y1, x2, y2))
        return(false);

    if (!vPauseEA) {
        m_button1.ColorBackground(clrMediumSeaGreen);
        m_button1.Color(clrBlack);
        if (iClosePositions) {
            m_button1.Text("LIMPAR E PAUSAR");
        } else {
            m_button1.Text("PAUSAR");
        }
    } else {        
        m_button1.ColorBackground(clrIndianRed);
        m_button1.Color(C'240,240,240'); 
        m_button1.Text("INICIAR");
    }        
    
    m_button1.Font(m_font);
    m_button1.FontSize(m_font_size);    
    m_button1.ColorBorder(C'64,60,66');
    
    if(!Add(m_button1)) {
        Print("Falha ao registrar botão");
        return(false);
    }
    
    Print("Botão registrado com ID=", m_button1.Id());
        
    ChartRedraw(0);
    return(true);
}


//+------------------------------------------------------------------+
//| Botão de limpar e pausar
//+------------------------------------------------------------------+
void CH9kPanel::OnClickButton1(void) {

    if (!vPauseEA) {
    
        closeAllOpenOrders(trade, MagicNumber);
        if(iClosePositions && HasPosition(MagicNumber)) {
            closeAllPositions(trade, MagicNumber);
        }
        
        vPauseEA = true;
        
        PrintFormat("[%I64d] Limpando e pausando", MagicNumber);
        
        m_button1.Text("INICIAR");
        m_button1.ColorBackground(clrIndianRed);
        m_button1.Color(C'240,240,240');
    } else {
        vPauseEA = false;
        PrintFormat("[%I64d] Play...", MagicNumber);
        
        if (iClosePositions) {
            m_button1.Text("LIMPAR E PAUSAR");
        } else {
            m_button1.Text("PAUSAR");
        }
        m_button1.ColorBackground(clrMediumSeaGreen);
        m_button1.Color(clrBlack);        
    }
    
    ChartRedraw(0);
    Sleep(200);
}

//+------------------------------------------------------------------+
//| Captura eventos do gráfico - botões                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {

    //PrintFormat("%d %I64d %.2f %s", id, lparam, dparam, sparam);
    if (iPanel)
        MyPanel.ChartEvent(id, lparam, dparam, sparam);

    return;

}
bool martketIsOpen() {
    datetime bar_time = iTime(_Symbol, PERIOD_M1, 0);

    // Compara com o dia do servidor, não com o local
    if (DayOnly(bar_time) != DayOnly(TimeTradeServer())){
        if (iPanel) {
            MyPanel.UpdateItem("status", "aguardando abertura");
            ChartRedraw(0);
        }
        return false;
    }
    
    return true;
}
//Função para saber se o mercado já abriu e não precisar limitar por horário
datetime DayOnly(datetime dt) {
    MqlDateTime t;
    TimeToStruct(dt, t);
    t.hour = t.min = t.sec = 0;
    return StructToTime(t);
}

// Estrutura removida - não há mais dados externos

//+------------------------------------------------------------------+
//| Funções VWAP (Volume Weighted Average Price)                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcula o VWAP (Volume Weighted Average Price)                    |
//+------------------------------------------------------------------+
double CalcularVWAP(ENUM_TIMEFRAMES timeframe, int numCandles)
{
    double vwap = 0.0;
    double volumeTotal = 0.0;
    double precoVolume = 0.0;
    
    // Redimensiona array se necessário
    if(ArraySize(ratesVWAP) != numCandles) {
        ArrayResize(ratesVWAP, numCandles);
        ArraySetAsSeries(ratesVWAP, true);
    }
    
    // Copia os dados do timeframe especificado
    if(CopyRates(_Symbol, timeframe, 0, numCandles, ratesVWAP) < numCandles) {
        LogMsg("ERRO: Falha ao copiar dados para cálculo do VWAP - Timeframe: " + 
               EnumToString(timeframe) + " | Candles: " + IntegerToString(numCandles), LOG_LEVEL_ERROR);
        return 0.0;
    }
    
    // Calcula VWAP
    for(int i = 0; i < numCandles; i++) {
        // Preço típico (High + Low + Close) / 3
        double precoTipico = (ratesVWAP[i].high + ratesVWAP[i].low + ratesVWAP[i].close) / 3.0;
        
        // Multiplica pelo volume
        precoVolume += precoTipico * ratesVWAP[i].tick_volume;
        volumeTotal += ratesVWAP[i].tick_volume;
    }
    
    // Calcula VWAP final
    if(volumeTotal > 0) {
        vwap = precoVolume / volumeTotal;
        vwap = NormalizeDouble(vwap, _Digits);
    }
    
    LogMsg("DEBUG: VWAP calculado - Timeframe: " + EnumToString(timeframe) + 
           " | Candles: " + IntegerToString(numCandles) + 
           " | Valor: " + DoubleToString(vwap, _Digits) + 
           " | Volume Total: " + DoubleToString(volumeTotal, 0), LOG_LEVEL_DEBUG);
    
    return vwap;
}

//+------------------------------------------------------------------+
//| Obtém o VWAP atual                                               |
//+------------------------------------------------------------------+
double ObterVWAPAtual(ENUM_TIMEFRAMES timeframe, int numCandles)
{
    static double vwapAnterior = 0.0;
    static datetime ultimoCalculo = 0;
    static ENUM_TIMEFRAMES ultimoTimeframe = PERIOD_CURRENT;
    static int ultimoNumCandles = 0;
    
    // Só recalcula se mudou o candle, timeframe ou número de candles
    if(ultimoCalculo != iTime(_Symbol, timeframe, 0) || 
       ultimoTimeframe != timeframe || 
       ultimoNumCandles != numCandles) {
        
        vwapAnterior = CalcularVWAP(timeframe, numCandles);
        ultimoCalculo = iTime(_Symbol, timeframe, 0);
        ultimoTimeframe = timeframe;
        ultimoNumCandles = numCandles;
    }
    
    return vwapAnterior;
}

//+------------------------------------------------------------------+
//| Verifica posição do preço em relação ao VWAP                      |
//+------------------------------------------------------------------+
ENUM_POSICAO_VWAP VerificarPosicaoVWAP(double preco, double vwap, double tolerancia = 0.0)
{
    if(vwap <= 0) return VWAP_NEUTRO; // VWAP inválido
    
    double diferenca = MathAbs(preco - vwap);
    double toleranciaAbs = tolerancia > 0 ? tolerancia : (vwap * 0.001); // 0.1% padrão
    
    if(preco > vwap + toleranciaAbs) {
        return VWAP_BULLISH; // Preço acima do VWAP
    } else if(preco < vwap - toleranciaAbs) {
        return VWAP_BEARISH; // Preço abaixo do VWAP
    } else {
        return VWAP_NEUTRO; // Preço próximo ao VWAP (zona neutra)
    }
}

//+------------------------------------------------------------------+
//| Aplica filtro VWAP nas entradas                                   |
//+------------------------------------------------------------------+
bool AplicarFiltroVWAP(double precoEntrada, ENUM_TIMEFRAMES timeframe, int numCandles, double tolerancia = 0.0,
ENUM_POSITION_TYPE typePos = NULL)
{
    double vwap = ObterVWAPAtual(timeframe, numCandles);
    if(vwap <= 0) return true; // Se VWAP inválido, permite entrada
    
    ENUM_POSICAO_VWAP posicaoVWAP = VerificarPosicaoVWAP(precoEntrada, vwap, tolerancia);
    
    // Log do filtro
    if(vwapLogDetalhado == sim) {
        string posicaoStr = "";
        switch(posicaoVWAP) {
            case VWAP_BULLISH: posicaoStr = "BULLISH (acima)"; break;
            case VWAP_BEARISH: posicaoStr = "BEARISH (abaixo)"; break;
            case VWAP_NEUTRO: posicaoStr = "NEUTRO (próximo)"; break;
        }
        
        LogMsg("DEBUG: Filtro VWAP - Preço: " + DoubleToString(precoEntrada, _Digits) + 
               " | VWAP: " + DoubleToString(vwap, _Digits) + 
               " | Timeframe: " + EnumToString(timeframe) + 
               " | Candles: " + IntegerToString(numCandles) + 
               " | Posição: " + posicaoStr, LOG_LEVEL_DEBUG);
    }
    
    // LÓGICA CORRIGIDA: Sempre verifica a direção da operação
    // COMPRA: Só permite se preço estiver acima do VWAP
    if( POSITION_TYPE_BUY == typePos && posicaoVWAP == VWAP_BULLISH) {
        if(vwapLogDetalhado == sim) {
            LogMsg("INFO: VWAP - COMPRA permitida (preço acima do VWAP)", LOG_LEVEL_INFO);
        }
        return true;
    }
    // VENDA: Só permite se preço estiver abaixo do VWAP  
    else if(POSITION_TYPE_SELL == typePos && posicaoVWAP == VWAP_BEARISH) {
        if(vwapLogDetalhado == sim) {
            LogMsg("INFO: VWAP - VENDA permitida (preço abaixo do VWAP)", LOG_LEVEL_INFO);
        }
        return true;
    }
    // Zona neutra: bloqueia ambas as operações
    else {
        if(vwapLogDetalhado == sim) {
            LogMsg("INFO: VWAP - Entrada BLOQUEADA (zona neutra próxima ao VWAP)", LOG_LEVEL_INFO);
        }
        return false;
    }
}

//+------------------------------------------------------------------+
//| Desenha linha VWAP no gráfico                                     |
//+------------------------------------------------------------------+
void DesenharVWAP()
{
    if(!mostrarVWAP) return;
    
    double vwap = ObterVWAPAtual(timeframeVWAP, candlesVWAP);
    if(vwap <= 0) return;
    
    string nomeVWAP = prefixoObjeto + "VWAP_" + EnumToString(timeframeVWAP) + "_" + IntegerToString(candlesVWAP);
    
    // Remove linha anterior se existir
    ObjectDelete(0, nomeVWAP);
    
    // Cria nova linha VWAP
    if(ObjectCreate(0, nomeVWAP, OBJ_HLINE, 0, 0, vwap)) {
        ObjectSetInteger(0, nomeVWAP, OBJPROP_COLOR, corVWAP);
        ObjectSetInteger(0, nomeVWAP, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, nomeVWAP, OBJPROP_WIDTH, espessuraVWAP);
        ObjectSetInteger(0, nomeVWAP, OBJPROP_BACK, true);
        ObjectSetInteger(0, nomeVWAP, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nomeVWAP, OBJPROP_HIDDEN, true);
        
        // Adiciona texto descritivo
        string nomeTexto = nomeVWAP + "_TEXT";
        ObjectDelete(0, nomeTexto);
        if(ObjectCreate(0, nomeTexto, OBJ_TEXT, 0, iTime(_Symbol, PERIOD_CURRENT, 0), vwap)) {
            ObjectSetString(0, nomeTexto, OBJPROP_TEXT, "VWAP " + EnumToString(timeframeVWAP) + " (" + IntegerToString(candlesVWAP) + ")");
            ObjectSetInteger(0, nomeTexto, OBJPROP_COLOR, corVWAP);
            ObjectSetInteger(0, nomeTexto, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, nomeTexto, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        }
        
        LogMsg("DEBUG: Linha VWAP desenhada - Timeframe: " + EnumToString(timeframeVWAP) + 
               " | Candles: " + IntegerToString(candlesVWAP) + 
               " | Preço: " + DoubleToString(vwap, _Digits), LOG_LEVEL_DEBUG);
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove objetos VWAP do gráfico                                    |
//+------------------------------------------------------------------+
void LimparVWAP()
{
    if(!mostrarVWAP) return;
    
    string nomeVWAP = prefixoObjeto + "VWAP_" + EnumToString(timeframeVWAP) + "_" + IntegerToString(candlesVWAP);
    string nomeTexto = nomeVWAP + "_TEXT";
    
    ObjectDelete(0, nomeVWAP);
    ObjectDelete(0, nomeTexto);
    
    ChartRedraw(0);
}


//+------------------------------------------------------------------+
//| Trailing Stop baseado em canais                                   |
//+------------------------------------------------------------------+
void GerenciarTrailingStop()
{
    if(!ativarTrailingStop || !posicaoAberta) return;
    
    // Só ativa após breakeven se configurado
    if(trailingAposBreakeven == sim && !breakevenAtivado) return;
    
    // Verifica se temos o canal de entrada válido
    if(canalEntradaIndex == -1) return;
    
    double precoAtual = 0.0;
    
    // Determina preço atual baseado na direção
    if(IsBought(MagicNumber)) {
        precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    } else if(IsSold(MagicNumber)) {
        precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    } else {
        return;
    }
    
    // LÓGICA CORRIGIDA: Calcula quantos canais o preço avançou desde a entrada
    int canaisAvancados = 0;
    
    if(IsBought(MagicNumber)) {
        // Para COMPRA: conta quantos canais o preço subiu desde a entrada
        for(int i = canalEntradaIndex; i >= 0; i--) {
            if(precoAtual >= linhasPreco[i]) {
                canaisAvancados = canalEntradaIndex - i;
                break;
            }
        }
    } else {
        // Para VENDA: conta quantos canais o preço desceu desde a entrada
        for(int i = canalEntradaIndex; i < ArraySize(linhasPreco); i++) {
            if(precoAtual <= linhasPreco[i]) {
                canaisAvancados = i - canalEntradaIndex;
                break;
            }
        }
    }
    
    // Ativa trailing quando atinge o número de canais configurado
    if(!trailingStopAtivado && canaisAvancados >= ativacaoTrailing) {
        trailingStopAtivado = true;
        
        if(trailingLogDetalhado == sim) {
            LogMsg("INFO: Trailing Stop ativado - Canais avançados: " + IntegerToString(canaisAvancados) + 
                   " | Canal entrada: " + IntegerToString(canalEntradaIndex) + 
                   " | Preço atual: " + DoubleToString(precoAtual, _Digits), LOG_LEVEL_INFO);
        }
    }
    
    // Se trailing está ativo, gerencia o Stop Loss
    if(trailingStopAtivado) {
        double novoStopLoss = 0.0;
        bool deveAtualizar = false;
        
        if(IsBought(MagicNumber)) {
            // Para COMPRA: Stop Loss fica alguns canais abaixo do preço atual
            int canalStop = MathMax(0, canalEntradaIndex - canaisAvancados + (int)distanciaTrailing);
            novoStopLoss = linhasPreco[canalStop] - (tickSize * 2);
            
            // Atualiza se o novo SL é melhor (mais alto)
            if(novoStopLoss > ultimoTrailingStop) {
                deveAtualizar = true;
            }
        } else {
            // Para VENDA: Stop Loss fica alguns canais acima do preço atual
            int canalStop = MathMin(ArraySize(linhasPreco) - 1, canalEntradaIndex + canaisAvancados - (int)distanciaTrailing);
            novoStopLoss = linhasPreco[canalStop] + (tickSize * 2);
            
            // Atualiza se o novo SL é melhor (mais baixo)
            if(novoStopLoss < ultimoTrailingStop || ultimoTrailingStop == 0.0) {
                deveAtualizar = true;
            }
        }
        
        // Aplica o novo Stop Loss se necessário
        if(deveAtualizar && novoStopLoss > 0) {
            changePositionsSL(trade, MagicNumber, roundPriceH9K(novoStopLoss, tickSize));
                ultimoTrailingStop = novoStopLoss;
                
                
                
                if(iPanel) {
                    MyPanel.UpdateItem("status", "trailing: " + DoubleToString(novoStopLoss, _Digits));
                    ChartRedraw(0);
                }
            
        }
    }
}

// Função para calcular o range médio da semana passada (últimos 7 dias)
double CalcularRangeSemanaPassada()
{
    double rangeTotal = 0.0;
    int diasValidos = 0;
    
    // Calcula o range dos últimos 7 dias (excluindo hoje)
    for(int dia = 1; dia <= 7; dia++) {
        double high = iHigh(_Symbol, PERIOD_D1, dia);
        double low = iLow(_Symbol, PERIOD_D1, dia);
        
        // Valida se os dados são válidos
        if(high > 0 && low > 0 && high > low) {
            double range = high - low;
            rangeTotal += range;
            diasValidos++;
            
            LogMsg("DEBUG: Dia " + IntegerToString(dia) + " - High: " + DoubleToString(high, _Digits) + 
                   " | Low: " + DoubleToString(low, _Digits) + 
                   " | Range: " + DoubleToString(range, _Digits), LOG_LEVEL_DEBUG);
        }
    }
    
    if(diasValidos > 0) {
        double rangeMedio = rangeTotal / diasValidos;
        
        LogMsg("INFO: Range da semana passada calculado - Dias válidos: " + IntegerToString(diasValidos) + 
               " | Range total: " + DoubleToString(rangeTotal, _Digits) + 
               " | Range médio: " + DoubleToString(rangeMedio, _Digits), LOG_LEVEL_DEBUG);
        
        return rangeMedio;
    } else {
        // Fallback: usa apenas o dia anterior
        double rangeFallback = iHigh(_Symbol, PERIOD_D1, 1) - iLow(_Symbol, PERIOD_D1, 1);
        LogMsg("WARNING: Usando fallback para range (dia anterior): " + DoubleToString(rangeFallback, _Digits), LOG_LEVEL_DEBUG);
        return rangeFallback;
    }
}