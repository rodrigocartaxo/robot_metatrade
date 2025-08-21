//+------------------------------------------------------------------+
//|                                           Price_Channel_Alert_EA.mq5 |
//|                                                                      |
//|                                                                      |
//+------------------------------------------------------------------+
#define     MName          "Price Channel"
#define     MVersion       "1.00"

#property copyright "Copyright 2024"
#property link      ""
#property version   MVersion
#property description "Expert Advisor para Price Channel com API externa"

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

// Enum para níveis de log
enum LOG_LEVEL {
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_INFO = 1,
    LOG_LEVEL_DEBUG = 2
};

//--- input parameters
input group " 🕝 Daytrade Window"
input ENUM_SIM_NAO i24h = nao; //Liga o modo 24h (forex)
input string iHoraIni  = "09:00:00"; //Hora inicio
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
input ENUM_ORIGIN orginSelect                 = VIANA; //Origem Lihas 
input int DesvioMaximoPontos                  = 10; // Desvio máximo permitido (slippage) em pontos
input int percentualStopLoss                  = 20 ; //Percentual Stoploss x Breakeven ref. Canal
input string iConfSaidas                      = "6:20,2:50,1:80,1:400";
input string InstanceName                     = "PC1";
input int posbreakeven                         = 1; // Ativar Brreakeven posicoes restantes


input group "=== Configurações Canais ==="
input int      EspessuraLinha                 = 1;      // Espessura das linhas
input ENUM_LINE_STYLE EstiloLinha             = STYLE_SOLID;  // Estilo das linhas



input group "=== Risk Management ==="
input ENUM_SIM_NAO riskManagement            = nao;   // Ativar Risk Management
input int    iDailyTarget                    = 10000;    // Meta de ganho 
input int    iLossTarget                     = 500;     // Loss máximo 
input double iDDTrigger                      = 300;     // Valor para ativar o drawdown
input double iDrawDown                       = 20;       // Percentual do valor para fechar posição


input group "=== Trailing Stop Inteligente ==="
input ENUM_SIM_NAO ativarTrailing = sim;     // Ativar trailing stop
input double percentualAtivacao = 80.0;      // % do lucro máximo para ativar
input int distanciaCanais = 2;               // Distância em canais para o stop
input double bufferSeguranca = 0.5;          // Buffer de segurança em %

input group "Outros"
input ENUM_SIM_NAO iClosePositions = sim; //Botão de Pause deve zerar posições
input ENUM_SIM_NAO iPanel = sim;             //Painel

// Variáveis globais
double vMaxProfit;
string prefixoObjeto = "PriceChannel_";
double tickSize; // Tamanho do tick do ativo
double incrementoTickCurrent = 0;

MqlRates rates[];
MqlRates rateGatilho;

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
//ENUM_ORIGIN orginSelect                 = VIANA;

ulong MagicNumber = 0.0; 

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

// Variáveis para trailing stop inteligente
bool trailingAtivo = false;
double lucroMaximoTrailing = 0.0;
bool trailingInicializado = false;


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


//+------------------------------------------------------------------+
//| Estrutura para armazenar dados do JSON                            |
//+------------------------------------------------------------------+
struct ConfiguracaoCanal {
    string ativo;
    double marcoZero;
    double tamanhoCanal;
    int nivel;
};

NivelCanal niveis[];
ConfiguracaoCanal configGeral;     // Torna global para uso em OnTick
ConfNivelSaidas niveisSaidas[];
ConfNivelSaidasHEDGING niveisSaidasHEDGING;
//double Volume = 0.0;

CH9kPanel MyPanel;
bool vPauseEA = false;    

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit(){
 
    string modo =  AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING?"NETTING":"HEDGING";
    
    LogMsg("Inciando EA em modo: " + modo , LOG_LEVEL_INFO);
    
    Comment(EnumToString(orginSelect));
    
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
    // Configurar os níveis
    ArrayResize(niveis, 3);
    
    // Carregar configuração apenas do nível selecionado da API
    int nivelSelecionado = (int)NivelAtivo;
    
    if(!CarregarConfiguracaoAPI(_Symbol, nivelSelecionado, configGeral))
    {
        LogMsg("ERRO: Falha ao carregar configuração do Nível " + IntegerToString(nivelSelecionado) + " da API", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    // Salva o dia da configuração inicial
    ultimoDiaConfig = iTime(_Symbol, PERIOD_D1, 0);
    
    // Configurar apenas o nível selecionado
    int nivelIndex = nivelSelecionado - 1;
    if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis))
    {
        niveis[nivelIndex].precoBase = configGeral.marcoZero;
        niveis[nivelIndex].incrementoTick = configGeral.tamanhoCanal;
        niveis[nivelIndex].nivel = configGeral.nivel;
        
        // Definir cor baseada no nível
        switch(nivelSelecionado)
        {
            case 1:
                niveis[nivelIndex].corBase = clrDodgerBlue;
                niveis[nivelIndex].prefixo = "Nivel1_";
                break;
            case 2:
                niveis[nivelIndex].corBase = clrMagenta;
                niveis[nivelIndex].prefixo = "Nivel2_";
                break;
            case 3:
                niveis[nivelIndex].corBase = clrOrange;
                niveis[nivelIndex].prefixo = "Nivel3_";
                break;
        }
        
        LogMsg("DEBUG: Nível " + IntegerToString(nivelSelecionado) + " configurado - Base: " + 
                DoubleToString(niveis[nivelIndex].precoBase, _Digits) + 
                " Incremento: " + DoubleToString(niveis[nivelIndex].incrementoTick, _Digits) +
                " Nível: " + IntegerToString(niveis[nivelIndex].nivel),LOG_LEVEL_DEBUG  );
    }
    else
    {
        LogMsg("ERRO: Nível inválido selecionado!", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    // Obter o tamanho do tick do ativo
    tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize == 0){
        LogMsg("ERRO: Falha ao obter o tamanho do tick do ativo!", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    LogMsg("Tamanho do tick do ativo " + _Symbol + ": " + DoubleToString(tickSize, _Digits), LOG_LEVEL_INFO);
    
    // Limpar objetos antigos
    LimparObjetos();
    
    // Criar apenas o nível selecionado
    if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis))
    {
        LogMsg("Configurando Nível " + IntegerToString(nivelSelecionado), LOG_LEVEL_INFO);
        LogMsg("Preço Base: " + DoubleToString(niveis[nivelIndex].precoBase, _Digits), LOG_LEVEL_DEBUG);
        LogMsg("Incremento: " + DoubleToString(niveis[nivelIndex].incrementoTick, 0), LOG_LEVEL_DEBUG);
        incrementoTickCurrent = niveis[nivelIndex].incrementoTick;
        
        // Calcular e criar linhas no início
        CalcularLinhasPreco(linhasPreco, niveis[nivelIndex]);
        CriarLinhasNivel(niveis[nivelIndex]);
    }
    else {
        LogMsg("ERRO: Nível inválido selecionado!", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    // Forçar redesenho inicial
    
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
        MyPanel.Create(0, StringFormat("%s %s", MName, MVersion), 0, 50, 70, 330, 500, _font_size);
        MyPanel.CreateItem("status", "Status:", 0);
        MyPanel.CreateItem("ropen", "Res. Aberto:", 1);
        MyPanel.CreateItem("rdia",  "Res. Dia:", 2);
        MyPanel.CreateItem("rweek", "Res. Semana:", 3); 
        MyPanel.CreateItem("iMagicNumber", "MagicNumber:", 4);
        MyPanel.CreateItem("channels", "Canais:", 5);
        MyPanel.CreateItem("risk", "Risk Mgmt:", 6);
        MyPanel.CreateItem("trailing", "Trailing:", 7);
                       
        
        MyPanel.UpdateItem("status", "inicializando..");
        MyPanel.UpdateItem("ropen", DoubleToString(OpenResult(MagicNumber), 2));
        MyPanel.UpdateItem("rdia", DoubleToString(DailyResult(MagicNumber), 2));
        MyPanel.UpdateItem("rweek", DoubleToString(weeklyResult(MagicNumber), 2));
        MyPanel.UpdateItem("iMagicNumber", (string)MagicNumber);
        MyPanel.UpdateItem("channels", StringFormat("Nível %d", NivelAtivo));
        MyPanel.UpdateItem("risk", riskManagement == sim ? "Ativo" : "Desativado");
        MyPanel.UpdateItem("trailing", ativarTrailing == sim ? "Ativo" : "Desativado");
        MyPanel.Run();
        ChartRedraw(0);
    }
    EventSetTimer(5); //Habilitando o timer do MQL5 para rodar a cada 5 segundos
   

    LogMsg(StringFormat("[%d] Inicializado com sucesso!", MagicNumber), LOG_LEVEL_INFO);
    // No início do OnInit, sincronizar a flag com o estado real
    posicaoAberta = has_open_position(MagicNumber);
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
     if (iPanel)
        MyPanel.Destroy(reason);
        
    EventKillTimer();
    LogMsg("EA finalizado. Motivo: " + IntegerToString(reason), LOG_LEVEL_INFO);
}

void OnTimer() {
     
     int pos_proces = count_pos_process();
     int numTotal  = ArraySize(niveisSaidasHEDGING.confSaidasHEDGING);
     
     // Trailing stop inteligente - SÓ APÓS BREAKEVEN
     if (ativarTrailing == sim && posicaoAberta && breakevenAtivado) {
         GerenciarTrailingStop();
     }
     
     if (!breakevenAtivado && (numTotal-pos_proces) == posbreakeven ){
         
         LogMsg("HasOrders(MagicNumber) "+(string) HasOrders(MagicNumber),LOG_LEVEL_INFO);
         LogMsg("precoEntrada "+(string) precoEntrada,LOG_LEVEL_INFO);
         
         if (IsBought(MagicNumber) ) {
           LogMsg("Ativar IsBought ",LOG_LEVEL_DEBUG);            
           double newSl =   precoEntrada - (2* tickSize);  
           changePositionsSL(trade, MagicNumber, roundPriceH9K(newSl,tickSize));        
           
         } else if (IsSold(MagicNumber) ) {
           LogMsg("Ativar IsSold ",LOG_LEVEL_DEBUG);           
           double newSl = precoEntrada = precoEntrada + (2* tickSize);  
           changePositionsSL(trade, MagicNumber, newSl );        
         }
      
         breakevenAtivado = true;
     }
   
   if (iPanel) {
        MyPanel.UpdateItem("ropen", DoubleToString(OpenResult(MagicNumber), 2));
        MyPanel.UpdateItem("rdia", DoubleToString(DailyResult(MagicNumber), 2));
        MyPanel.UpdateItem("rweek", DoubleToString(weeklyResult(MagicNumber), 2));
        
        // Atualizar status do trailing
        if (ativarTrailing == sim && posicaoAberta && breakevenAtivado) {
            if (trailingAtivo) {
                MyPanel.UpdateItem("trailing", "Ativo - " + DoubleToString(lucroMaximoTrailing, 2));
            } else {
                MyPanel.UpdateItem("trailing", "Aguardando - " + DoubleToString(percentualAtivacao, 1) + "%");
            }
        } else if (ativarTrailing == sim) {
            MyPanel.UpdateItem("trailing", "Aguardando breakeven");
        }
        
        // Atualizar status geral
        if (vPauseEA) {
            MyPanel.UpdateItem("status", "pausado");
        } else if (has_open_position(MagicNumber)) {
            MyPanel.UpdateItem("status", "posição aberta");
        } else if (HasOrders(MagicNumber)) {
            MyPanel.UpdateItem("status", "aguardando entrada");
        } else {
            MyPanel.UpdateItem("status", "aguardando canal");
        }
        
        ChartRedraw(0);
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
    if (vPauseEA) return;
    
    // Sincroniza a flag com o status real da corretora
    if (isNewBar(Periodo)){
       posicaoAberta = has_open_position(MagicNumber);
    }
    
    
    // Novo: verifica se mudou o dia e recarrega config se necessário
    datetime diaAtual = iTime(_Symbol, PERIOD_D1, 0);
    int nivelSelecionado = (int)NivelAtivo;
    int nivelIndex = nivelSelecionado - 1;
    if (diaAtual != ultimoDiaConfig) {
        if(CarregarConfiguracaoAPI(_Symbol, nivelSelecionado, configGeral)) {
            if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis)) {
                niveis[nivelIndex].precoBase = configGeral.marcoZero;
                niveis[nivelIndex].incrementoTick = configGeral.tamanhoCanal;
                niveis[nivelIndex].nivel = configGeral.nivel;
                incrementoTickCurrent = niveis[nivelIndex].incrementoTick;
                precoEntrada = 0.0;
                breakevenAtivado = false;
                // Reset das variáveis de trailing para novo dia
                trailingAtivo = false;
                trailingInicializado = false;
                lucroMaximoTrailing = 0.0;
                // Recalcular e recriar linhas para o novo dia
                LimparObjetos();
                ArrayResize(niveisSaidasHEDGING.confSaidasHEDGING, 0);
                niveisSaidasHEDGING.numeroTicket = 0;
                CalcularLinhasPreco(linhasPreco, niveis[nivelIndex]);
                CriarLinhasNivel(niveis[nivelIndex]);
                if (iPanel)
                  MyPanel.UpdateItem("status", "novo dia carregado");
                ChartRedraw(0);
                LogMsg("Configuração do canal recarregada para o novo dia.", LOG_LEVEL_INFO);
            }
            ultimoDiaConfig = diaAtual;
        } else {
            LogMsg("ERRO: Falha ao recarregar configuração da API no novo dia.", LOG_LEVEL_ERROR);
        }
    }
   
   if (!i24h && !allowed_by_hour(iHoraIni, iHoraFim)) {
        closeAllPositions(trade, MagicNumber);
        closeAllOpenOrders(trade, MagicNumber);        
        LiberarLockMeta();
        LiberarLockLoss();
        LiberarLockDrawdown();
        vDDTriggerActive = false;
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
     if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis)){
            VerificarGatilhos(linhasPreco);
        }
   
    
   
    // Cancela ordens pendentes de parciais se não houver mais posição aberta
    if (!posicaoAberta) {
        CancelarOrdensParciais();
        breakevenAtivado = false;
        niveisSaidasHEDGING.numeroTicket = 0;
        CalcularLinhasPreco(linhasPreco, niveis[nivelIndex]);
        
        // Reset das variáveis de trailing
        trailingAtivo = false;
        trailingInicializado = false;
        lucroMaximoTrailing = 0.0;
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
       
        if (iPanel)
                  MyPanel.UpdateItem("status", "protecao feita");
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
         if (iPanel)
                  MyPanel.UpdateItem("status", "protecao feita");
                  
         continue;
       } 
        
   }
      
     

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
void CriarLinhasNivel(NivelCanal &nivel)
{
    
    CalcularLinhasPreco(linhasPreco, nivel);
    
    datetime tempo = TimeCurrent();
    double pontoPip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    LogMsg("DEBUG: Criando linhas para nível - Base: " + DoubleToString(nivel.precoBase, _Digits) + 
            " Incremento: " + DoubleToString(nivel.incrementoTick, _Digits) +  " Nivel : "+ IntegerToString(nivel.nivel),LOG_LEVEL_DEBUG  );
    
    for(int i = 0; i < ArraySize(linhasPreco); i++)
    {
        string nomeObjeto = prefixoObjeto + nivel.prefixo + IntegerToString(i);
        
        if(!ObjectCreate(0, nomeObjeto, OBJ_HLINE, 0, 0, linhasPreco[i]))
        {
            LogMsg("ERRO: Falha ao criar linha " + nomeObjeto, LOG_LEVEL_ERROR);
            continue;
        }
        
        ObjectSetInteger(0, nomeObjeto, OBJPROP_COLOR, ColorBrighten(nivel.corBase, 20 * i));
        ObjectSetInteger(0, nomeObjeto, OBJPROP_STYLE, EstiloLinha);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_WIDTH, EspessuraLinha);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_BACK, true);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nomeObjeto, OBJPROP_HIDDEN, true);
        
        if(MostrarPreco == sim)
        {
            string nomeTexto = prefixoObjeto + nivel.prefixo + "txt_" + IntegerToString(i);
            double precoTexto = linhasPreco[i] + (20 * pontoPip);
            
            if(!ObjectCreate(0, nomeTexto, OBJ_TEXT, 0, tempo, precoTexto))
            {
                LogMsg("ERRO: Falha ao criar texto " + nomeTexto, LOG_LEVEL_ERROR);
                continue;
            }
            
            ObjectSetString(0, nomeTexto, OBJPROP_TEXT, nivel.prefixo + DoubleToString(linhasPreco[i], _Digits));
            ObjectSetInteger(0, nomeTexto, OBJPROP_COLOR, ColorBrighten(nivel.corBase, 20 * i));
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
    for(int i = 0; i < ArraySize(linhas); i++)
    {
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
    double incremento = incrementoTickCurrent;
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
    // Compra: fechamento acima da linha -> EXECUTA COMPRA
    if(rates[0].close > linhas[indice_linha] 
       && rateGatilho.high < SymbolInfoDouble(_Symbol, SYMBOL_BID) ){
        double takeProfit = EncontrarProximoNivelSuperior(linhas, indice_linha, rates[0].close); // TP acima
        if(takeProfit > 0){
            precoEntrada = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double stop_calc = linhas[indice_linha] - (incremento * (percentualStopLoss/100.0));
            double minDist = MathMax(stopLevel, tickSize * 2);
            double stop_loss = MathMin(roundPriceH9K(stop_calc, tickSize), precoEntrada - tickSize);
            if (stop_loss >= precoEntrada) stop_loss = precoEntrada - tickSize;
            if ((precoEntrada - stop_loss) < minDist)
                stop_loss = precoEntrada - minDist;
            if(stop_loss < precoEntrada && takeProfit > precoEntrada &&
               (precoEntrada - stop_loss > stopLevel) && (takeProfit - precoEntrada > stopLevel)) {
                if (ExecutarCompra(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), 0)) {
                    ultimoCandleEntrada = rateGatilho.time;
                    canalEntradaIndex = indice_linha; // Salva o canal da entrada
                    posicaoTicket = trade.ResultOrder(); // Salva o ticket da posição aberta                    
                     for (int i = 0; i < ArraySize(niveisSaidas); i++) {
                           double tp =   roundPriceH9K(precoEntrada,tickSize) + (incremento * (niveisSaidas[i].percentSaida/100.0));
                           double vol = MathMax(NormalizeDouble(MathRound(niveisSaidas[i].qtdContratos / volumeStep) * volumeStep, 2), minVolume); 
                            if ( AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING){
                              trade.SellLimit(vol, roundPriceH9K(tp, tickSize), _Symbol, 0, 0, ORDER_TIME_GTC, 0,  EnumToString(orginSelect) + "Parcial "+ (string)(i+1) );
                            }else if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){
                              niveisSaidasHEDGING.numeroTicket = posicaoTicket;
                              niveisSaidasHEDGING.posType = POSITION_TYPE_BUY;
                              int tamanho = ArraySize(niveisSaidasHEDGING.confSaidasHEDGING);
                              ArrayResize(niveisSaidasHEDGING.confSaidasHEDGING, tamanho + 1);
                              niveisSaidasHEDGING.confSaidasHEDGING[tamanho].qtdContratos =vol;
                              niveisSaidasHEDGING.confSaidasHEDGING[tamanho].valorSaida = tp;
                              niveisSaidasHEDGING.confSaidasHEDGING[tamanho].processada = false;
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
        double takeProfit = EncontrarProximoNivelInferior(linhas, indice_linha, rates[0].close); // TP abaixo
        if(takeProfit > 0){
            precoEntrada = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double stop_calc = linhas[indice_linha] + (incremento * (percentualStopLoss/100.0));
            double minDist = MathMax(stopLevel, tickSize * 2);
            double stop_loss = MathMax(roundPriceH9K(stop_calc, tickSize), precoEntrada + tickSize);
            if (stop_loss <= precoEntrada) stop_loss = precoEntrada + tickSize;
            if ((stop_loss - precoEntrada) < minDist)
                stop_loss = precoEntrada + minDist;
            
            if(stop_loss > precoEntrada && takeProfit < precoEntrada &&
               (stop_loss - precoEntrada > stopLevel) && (precoEntrada - takeProfit > stopLevel)) {
                if (ExecutarVenda(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), 0)) {
                    ultimoCandleEntrada = rateGatilho.time;
                    canalEntradaIndex = indice_linha; // Salva o canal da entrada
                    posicaoTicket = trade.ResultOrder(); // Salva o ticket da posição aberta
                    for (int i = 0; i < ArraySize(niveisSaidas); i++) {
                           double tp =   roundPriceH9K(precoEntrada,tickSize) - (incremento * (niveisSaidas[i].percentSaida/100.0));
                           double vol = MathMax(NormalizeDouble(MathRound(niveisSaidas[i].qtdContratos / volumeStep) * volumeStep, 2), minVolume);
                           if ( AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING){
                              trade.BuyLimit(vol, roundPriceH9K(tp, tickSize), _Symbol, 0, 0, ORDER_TIME_GTC, 0,  EnumToString(orginSelect) + "Parcial "+ (string)(i+1) );                     
                           }else if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){
                              niveisSaidasHEDGING.numeroTicket = posicaoTicket;
                              niveisSaidasHEDGING.posType = POSITION_TYPE_SELL;
                              int tamanho = ArraySize(niveisSaidasHEDGING.confSaidasHEDGING);
                              ArrayResize(niveisSaidasHEDGING.confSaidasHEDGING, tamanho + 1);
                              niveisSaidasHEDGING.confSaidasHEDGING[tamanho].qtdContratos =vol;
                              niveisSaidasHEDGING.confSaidasHEDGING[tamanho].valorSaida = tp;
                              niveisSaidasHEDGING.confSaidasHEDGING[tamanho].processada = false;
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
    bool order_sent = trade.Buy(volume, _Symbol, preco_entrada, stop_loss, take_profit, EnumToString(orginSelect) + " : " + _Symbol);
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
    bool order_sent = trade.Sell(volume, _Symbol, preco_entrada, stop_loss, take_profit, EnumToString(orginSelect) + " : " + _Symbol);
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
        
        if(elapsed_time >= MAX_WAIT_TIME_MS || HasPosition(magicNumber) == 0) {
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

//+------------------------------------------------------------------+
//| Função para fazer chamada HTTP para endpoint externo              |
//+------------------------------------------------------------------+
string FazerChamadaHTTP(string symbol, int nivel)
{
    string url = "http://37.27.215.180:8080/api/fonte-dados/" + symbol + "/" + IntegerToString(nivel)+"/" + EnumToString(orginSelect);
    
    LogMsg("DEBUG: Fazendo chamada HTTP para: " + url, LOG_LEVEL_DEBUG);
    
    // Array para armazenar os dados da resposta
    uchar post_data[];
    uchar result_data[];
    string headers;
    
    // Faz a requisição HTTP
    int result = WebRequest("GET", url, headers, 5000, post_data, result_data, headers);
    
    if(result == 200) // Sucesso
    {
        string response = CharArrayToString(result_data);
        LogMsg("DEBUG: Resposta HTTP recebida: " + response, LOG_LEVEL_DEBUG);
        return response;
    }
    else
    {
        // Códigos de erro detalhados
        string errorMsg = "";
        switch(result)
        {
            case -1:
                errorMsg = "WebRequest não permitido. Verifique: Ferramentas -> Opções -> Expert Advisors ->  lista";
                break;
            case -2:
                errorMsg = "URL inválida";
                break;
            case -3:
                errorMsg = "Timeout da requisição";
                break;
            case -4:
                errorMsg = "Falha na requisição HTTP";
                break;
            default:
                errorMsg = "Erro desconhecido";
                break;
        }
        
        LogMsg("ERRO: Falha na chamada HTTP. Código: " + IntegerToString(result) + " - " + errorMsg, LOG_LEVEL_ERROR);
        LogMsg("INFO: Usando configuração padrão como fallback", LOG_LEVEL_INFO);
        return CriarConfiguracaoPadrao(symbol, nivel);
    }
}

//+------------------------------------------------------------------+
//| Função para criar configuração padrão quando API não está disponível |
//+------------------------------------------------------------------+
string CriarConfiguracaoPadrao(string symbol, int nivel)
{
    string config = "{\"ativo\":\"" + symbol + "\",\"marcoZero\":244355.00,\"tamanhoCanal\":7231.37,\"nivel\":" + DoubleToString(nivel) + "}";
    LogMsg("DEBUG: Configuração padrão criada para nível " + IntegerToString(nivel) + ": " + config, LOG_LEVEL_DEBUG);
    return config;
}

//+------------------------------------------------------------------+
//| Função para processar resposta JSON da API                        |
//+------------------------------------------------------------------+
bool ProcessarRespostaAPI(string response, ConfiguracaoCanal &config)
{
    if(StringLen(response) == 0)
    {
        LogMsg("ERRO: Resposta vazia da API", LOG_LEVEL_ERROR);
        return false;
    }
    
    // Remove espaços e quebras de linha
    StringTrimLeft(response);
    StringTrimRight(response);
    
    LogMsg("DEBUG: Processando resposta JSON: " + response, LOG_LEVEL_DEBUG);
    
    // Extrai os valores usando StringFind e StringSubstr
    int posAtivo = StringFind(response, "\"ativo\":");
    int posMarcoZero = StringFind(response, "\"marcoZero\":");
    int posTamanhoCanal = StringFind(response, "\"tamanhoCanal\":");
    int posNivel = StringFind(response, "\"nivel\":");
    
    if(posAtivo >= 0 && posMarcoZero >= 0 && posTamanhoCanal >= 0 && posNivel >= 0)
    {
        // Extrai o Ativo
        int startAtivo = StringFind(response, "\"", posAtivo + 8) + 1;
        int endAtivo = StringFind(response, "\"", startAtivo);
        config.ativo = StringSubstr(response, startAtivo, endAtivo - startAtivo);
        
        // Extrai o Marco Zero
        int startMarcoZero = StringFind(response, ":", posMarcoZero) + 1;
        int endMarcoZero = StringFind(response, ",", startMarcoZero);
        if(endMarcoZero == -1) endMarcoZero = StringFind(response, "}", startMarcoZero);
        config.marcoZero = StringToDouble(StringSubstr(response, startMarcoZero, endMarcoZero - startMarcoZero));
        
        // Extrai o Tamanho do Canal
        int startTamanhoCanal = StringFind(response, ":", posTamanhoCanal) + 1;
        int endTamanhoCanal = StringFind(response, ",", startTamanhoCanal);
        if(endTamanhoCanal == -1) endTamanhoCanal = StringFind(response, "}", startTamanhoCanal);
        config.tamanhoCanal = StringToDouble(StringSubstr(response, startTamanhoCanal, endTamanhoCanal - startTamanhoCanal));
        
        // Extrai o Nível (agora é inteiro)
        int startNivel = StringFind(response, ":", posNivel) + 1;
        int endNivel = StringFind(response, ",", startNivel);
        if(endNivel == -1) endNivel = StringFind(response, "}", startNivel);
        string nivelStr = StringSubstr(response, startNivel, endNivel - startNivel);
        StringTrimLeft(nivelStr);
        StringTrimRight(nivelStr);
        config.nivel = StringToInteger(nivelStr);
        
        LogMsg("Configuração carregada com sucesso da API:", LOG_LEVEL_INFO);
        LogMsg("Ativo: " + config.ativo, LOG_LEVEL_INFO);
        LogMsg("Marco Zero: " + DoubleToString(config.marcoZero, _Digits), LOG_LEVEL_DEBUG);
        LogMsg("Tamanho Canal: " + DoubleToString(config.tamanhoCanal, _Digits), LOG_LEVEL_DEBUG);
        LogMsg("Nível: " + IntegerToString(config.nivel), LOG_LEVEL_INFO);
        
        return true;
    }
    
    LogMsg("ERRO: Formato JSON inválido na resposta da API", LOG_LEVEL_ERROR);
    return false;
}

//+------------------------------------------------------------------+
//| Função para carregar configuração da API                          |
//+------------------------------------------------------------------+
bool CarregarConfiguracaoAPI(string symbol, int nivel, ConfiguracaoCanal &config)
{
    string response = FazerChamadaHTTP(symbol, nivel);
    if(StringLen(response) > 0)
    {
        return ProcessarRespostaAPI(response, config);
    }
    return false;
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
    
    // Informações do trailing stop
    if (ativarTrailing == sim) {
        string statusTrailing = "Desativado";
        if (posicaoAberta && breakevenAtivado) {
            if (trailingAtivo) {
                statusTrailing = "Ativo - Max: " + DoubleToString(lucroMaximoTrailing, 2);
            } else {
                statusTrailing = "Aguardando " + DoubleToString(percentualAtivacao, 1) + "%";
            }
        } else if (posicaoAberta) {
            statusTrailing = "Aguardando breakeven";
        }
        LogMsg("Trailing Stop: " + statusTrailing, LOG_LEVEL_INFO);
    }
    
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
           LogMsg("Limpando as variaveis", LOG_LEVEL_INFO);
           
           // Reset das variáveis de trailing
           trailingAtivo = false;
           trailingInicializado = false;
           lucroMaximoTrailing = 0.0;
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

//+------------------------------------------------------------------+
//| Gerencia o trailing stop inteligente                              |
//+------------------------------------------------------------------+
void GerenciarTrailingStop() {
    if (!posicaoAberta || !breakevenAtivado) return;
    
    double lucroAtual = DailyResult(MagicNumber) + OpenResult(MagicNumber);
    
    // Inicializa o trailing na primeira execução
    if (!trailingInicializado) {
        lucroMaximoTrailing = lucroAtual;
        trailingInicializado = true;
        LogMsg("Trailing stop inicializado com lucro: " + DoubleToString(lucroMaximoTrailing, 2), LOG_LEVEL_INFO);
    }
    
    // Atualiza lucro máximo se necessário
    if (lucroAtual > lucroMaximoTrailing) {
        lucroMaximoTrailing = lucroAtual;
        LogMsg("Novo lucro máximo para trailing: " + DoubleToString(lucroMaximoTrailing, 2), LOG_LEVEL_DEBUG);
    }
    
    // Verifica se deve ativar o trailing
    if (!trailingAtivo && lucroAtual >= (lucroMaximoTrailing * percentualAtivacao / 100.0)) {
        trailingAtivo = true;
        LogMsg("Trailing stop ativado! Lucro atual: " + DoubleToString(lucroAtual, 2) + 
               " (≥ " + DoubleToString(percentualAtivacao, 1) + "% do máximo)", LOG_LEVEL_INFO);
    }
    
    // Se ativo, gerencia o stop
    if (trailingAtivo) {
        AjustarStopTrailing();
    }
}

//+------------------------------------------------------------------+
//| Ajusta o stop loss baseado no trailing inteligente               |
//+------------------------------------------------------------------+
void AjustarStopTrailing() {
    if (!posicaoAberta || !trailingAtivo || !breakevenAtivado) return;
    
    // Obtém informações da posição atual
    ulong ticket = 0;
    ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY;
    double precoEntrada = 0.0;
    double stopAtual = 0.0;
    
    // Encontra a posição aberta
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionSelectByTicket(PositionGetTicket(i))) {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol && 
                PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
                ticket = PositionGetTicket(i);
                posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
                stopAtual = PositionGetDouble(POSITION_SL);
                break;
            }
        }
    }
    
    if (ticket == 0) {
        LogMsg("ERRO: Não foi possível encontrar posição para trailing", LOG_LEVEL_ERROR);
        return;
    }
    
    // Calcula o novo stop baseado nos canais
    double novoStop = CalcularNovoStopTrailing(posType, canalEntradaIndex);
    
    if (novoStop <= 0) {
        LogMsg("ERRO: Falha ao calcular novo stop para trailing", LOG_LEVEL_ERROR);
        return;
    }
    
    // Verifica se o novo stop é favorável
    if (DeveAtualizarStop(posType, stopAtual, novoStop)) {
        // Executa a atualização do stop
        if (AtualizarStopLoss(ticket, novoStop)) {
            LogMsg("Trailing Stop atualizado: " + DoubleToString(stopAtual, _Digits) + 
                   " → " + DoubleToString(novoStop, _Digits), LOG_LEVEL_INFO);
        }
    }
}

//+------------------------------------------------------------------+
//| Calcula o novo stop baseado nos canais                           |
//+------------------------------------------------------------------+
double CalcularNovoStopTrailing(ENUM_POSITION_TYPE posType, int canalEntrada) {
    if (canalEntrada < 0 || canalEntrada >= ArraySize(linhasPreco)) {
        LogMsg("ERRO: Canal de entrada inválido para trailing", LOG_LEVEL_ERROR);
        return 0.0;
    }
    
    double novoStop = 0.0;
    double incremento = incrementoTickCurrent;
    
    if (posType == POSITION_TYPE_BUY) {
        // Para COMPRA: stop abaixo da entrada (canal inferior)
        int canalStop = canalEntrada + distanciaCanais;
        if (canalStop < ArraySize(linhasPreco)) {
            novoStop = linhasPreco[canalStop];
            // Adiciona buffer de segurança
            novoStop = novoStop - (incremento * (bufferSeguranca / 100.0));
        } else {
            // Se não há canal suficiente, usa o último disponível
            novoStop = linhasPreco[ArraySize(linhasPreco) - 1];
        }
    } else if (posType == POSITION_TYPE_SELL) {
        // Para VENDA: stop acima da entrada (canal superior)
        int canalStop = canalEntrada - distanciaCanais;
        if (canalStop >= 0) {
            novoStop = linhasPreco[canalStop];
            // Adiciona buffer de segurança
            novoStop = novoStop + (incremento * (bufferSeguranca / 100.0));
        } else {
            // Se não há canal suficiente, usa o primeiro disponível
            novoStop = linhasPreco[0];
        }
    }
    
    // Arredonda para o tick size correto
    novoStop = roundPriceH9K(novoStop, tickSize);
    
    return novoStop;
}

//+------------------------------------------------------------------+
//| Verifica se deve atualizar o stop loss                           |
//+------------------------------------------------------------------+
bool DeveAtualizarStop(ENUM_POSITION_TYPE posType, double stopAtual, double novoStop) {
    if (stopAtual == 0) return true; // Primeira vez
    
    if (posType == POSITION_TYPE_BUY) {
        // Para COMPRA: só atualiza se o novo stop for MAIOR (mais favorável)
        return (novoStop > stopAtual);
    } else if (posType == POSITION_TYPE_SELL) {
        // Para VENDA: só atualiza se o novo stop for MENOR (mais favorável)
        return (novoStop < stopAtual);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Executa a atualização do stop loss                               |
//+------------------------------------------------------------------+
bool AtualizarStopLoss(ulong ticket, double novoStop) {
    // Verifica se o novo stop respeita o stop level mínimo
    double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double precoAtual = 0.0;
    
    if (PositionSelectByTicket(ticket)) {
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        precoAtual = PositionGetDouble(POSITION_PRICE_OPEN);
        
        if (posType == POSITION_TYPE_BUY) {
            if ((precoAtual - novoStop) < stopLevel) {
                LogMsg("ERRO: Novo stop muito próximo para COMPRA", LOG_LEVEL_ERROR);
                return false;
            }
        } else if (posType == POSITION_TYPE_SELL) {
            if ((novoStop - precoAtual) < stopLevel) {
                LogMsg("ERRO: Novo stop muito próximo para VENDA", LOG_LEVEL_ERROR);
                return false;
            }
        }
    }
    
    // Executa a modificação
    trade.PositionModify(ticket, novoStop, 0);
    uint retcode = trade.ResultRetcode();
    
    if (retcode == TRADE_RETCODE_DONE) {
        LogMsg("SUCESSO: Stop loss atualizado para " + DoubleToString(novoStop, _Digits), LOG_LEVEL_INFO);
        return true;
    } else {
        LogMsg("ERRO: Falha ao atualizar stop loss. Retcode: " + IntegerToString(retcode), LOG_LEVEL_ERROR);
        return false;
    }
}
