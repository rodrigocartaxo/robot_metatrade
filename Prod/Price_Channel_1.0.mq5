//+------------------------------------------------------------------+
//|                                           Price_Channel_Alert_EA.mq5 |
//|                                                                      |
//|                                                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property description "Expert Advisor para Price Channel com API externa"

//+------------------------------------------------------------------+
//| Sugestões para Futuras Melhorias:                                  |
//|                                                                     |
//| 1. Indicadores Técnicos:                                           |
//|    - Adicionar mais indicadores para filtrar sinais                |
//|    - Implementar confirmações com médias móveis                    |
//|    - Usar osciladores para confirmar momentum                      |
//|                                                                     |
//| 2. Painel Informativo:                                             |
//|    - Mostrar estatísticas de trades                               |
//|    - Exibir resultados históricos                                 |
//|    - Calcular taxa de acerto                                      |
//|                                                                     |
//| 3. Gerenciamento de Posições:                                      |
//|    - Implementar breakeven automático                             |
//|    - Adicionar trailing stop                                      |
//|    - Criar sistema de saída parcial                               |
//|                                                                     |
//| 4. Expansão do Sistema:                                            |
//|    - Adicionar mais níveis de canais                              |
//|    - Permitir configuração dinâmica de níveis                     |
//|    - Implementar outros tipos de canais                           |
//|                                                                     |
//| 5. Filtros Adicionais:                                            |
//|    - Adicionar filtros de volatilidade                           |
//|    - Implementar filtros de spread                               |
//+------------------------------------------------------------------+

// Inclusão de bibliotecas necessárias
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <.\Personal\H9k_Includes\H9k_libs_4.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>



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
input group "Daytrade Window"
input ENUM_SIM_NAO i24h = nao; //Liga o modo 24h (forex)
input string iHoraIni  = "09:05:00"; //Hora inicio
input string iHoraFim  = "17:30:00"; //Hora fim
input ENUM_SIM_NAO AtivarInterval             = sim;      // Ativar Hora de pausa 
input string iHoraInterval1                   = "12:00"; //Hora Inicio Pausa
input string iHoraInterval2                   = "13:30"; //Hora Fim Pausa


// Parâmetros gerais
input group "=== Configurações Gerais ==="
input ENUM_TIMEFRAMES Periodo                 = PERIOD_M2;  // Período do Gráfico
input ENUM_CHANNEL_LEVEL NivelAtivo           = NIVEL_1;  // Nível do Canal a Exibir
input double   Volume                         = 10;       // Alavacagem Lotes
input ENUM_SIM_NAO MostrarLogs                = sim;      // Mostrar logs detalhados
input LOG_LEVEL LogLevel                      = LOG_LEVEL_INFO; // Nível de log exibido
input ENUM_SIM_NAO MostrarPreco               = sim;     // Mostrar preço nas linhas
input int numeroLinhas                        =  25 ; //Numero de canais
input int percentualStopLoss                  =  75 ; //Percentual stop loss ref. Canal
input ENUM_ORIGIN orginSelect                 = VIANA; //Origem Lihas 


input group "=== Configurações Canais ==="
input int      EspessuraLinha                 = 1;      // Espessura das linhas
input ENUM_LINE_STYLE EstiloLinha             = STYLE_SOLID;  // Estilo das linhas



input group "=== Risk Management ==="
input ENUM_SIM_NAO riskManagement            = sim;   // Ativar Risk Management
input int    iDailyTarget                    = 10000;    // Meta de ganho 
input int    iLossTarget                     = 500;     // Loss máximo 
input double iDDTrigger                      = 300;     // Valor para ativar o drawdown
input double iDrawDown                       = 20;       // Percentual do valor para fechar posição


// Variáveis globais
double ultimoPreco,vMaxProfit;
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

ulong MagicNumber = 0.0; 

MyMagicNumber myMagicNumber;




// Variáveis globais de estatísticas
int qtdOperacoes = 0;
int qtdGain = 0;
int qtdLoss = 0;

datetime ultimoCandleEntrada = 0; // Trava para apenas uma entrada por candle de gatilho
datetime ultimoDiaConfig = 0; // Novo: controle do último dia de configuração


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
    ulong hash = 5381;
    string key = eaName + ":" + symbol;
    for(int i = 0; i < StringLen(key); i++) {
        hash = ((hash << 5) + hash) + (uchar)StringGetCharacter(key, i); // hash * 33 + c
    }
    // Garante que o número não seja zero e caiba em 9 dígitos (limite do MetaTrader)
    hash = hash % 1000000000ULL;
    if(hash == 0) hash = 1;
    return hash;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit(){
    
    ChartSetSymbolPeriod(0, _Symbol, Periodo);
    ChartSetInteger(0,CHART_SHOW_GRID,false);
    
    ResetLastError();
        
    if (AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO) {
        LogMsg("Este EA só pode ser executado em contas em DEMO.", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    MagicNumber = CalcularMagicNumber(MQLInfoString(MQL_PROGRAM_NAME)+EnumToString(orginSelect), _Symbol); 
    
     
    
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
        CriarLinhasNivel(niveis[nivelIndex]);
    }
    else {
        LogMsg("ERRO: Nível inválido selecionado!", LOG_LEVEL_ERROR);
        return INIT_FAILED;
    }
    
    // Forçar redesenho inicial
    ChartSetInteger(0, CHART_AUTOSCROLL, true);
    ChartSetInteger(0, CHART_SHIFT, true);
    ChartRedraw(0);
    
    // Configurações de trading
    //trade.SetDeviationInPoints(10); // Desvio máximo do preço
    trade.SetTypeFilling(ORDER_FILLING_RETURN); // Tipo de preenchimento
    trade.SetExpertMagicNumber(MagicNumber); // Número mágico do EA
    trade.LogLevel(LOG_LEVEL_ALL); // Nível de log
    trade.SetAsyncMode(false); // Modo síncrono para garantir execução correta
    
    if((DailyResult(MagicNumber) + OpenResult(MagicNumber)) <= 0.95*iDailyTarget) {
        LiberarLockMeta();
        LiberarLockLoss();
        LiberarLockDrawdown();
    }
    
    LogMsg(StringFormat("[%d] Inicializado com sucesso!", MagicNumber), LOG_LEVEL_INFO);
    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
    
    // Limpar todos os objetos, incluindo triggers
    ObjectsDeleteAll(0, prefixoObjeto);
    ChartRedraw(0);
    
    ArrayFree(rates);
    LogMsg("EA finalizado. Motivo: " + IntegerToString(reason), LOG_LEVEL_INFO);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick(){
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
                LimparObjetos();
                CriarLinhasNivel(niveis[nivelIndex]);
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
   
   if(AtivarInterval == sim){
      if(EstaNoHorarioDePausa(iHoraInterval1,iHoraInterval2)){
         if (isNewBar(Periodo)) {
            LogMsg("INFO: Hora de intervalo ativada ", LOG_LEVEL_INFO);
            PrintEstatisticasRobo();
         }
         return;
      }  
    }
    
    if (riskManagement == sim){
         GerenciarRisk();
     }   
   

    if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis)){
        
        if (isNewBar(Periodo)){
           CalcularLinhasPreco(linhasPreco, niveis[nivelIndex]);
           AtualizarLinhasNivel(niveis[nivelIndex]);
           ChartRedraw(0);
        }
        VerificarGatilhos(linhasPreco);
        
    }
    
    
    
    
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
        linhas[i] = nivel.precoBase + (i * nivel.incrementoTick);
    }
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
//| Arredonda o preço de acordo com o tick size do ativo              |
//+------------------------------------------------------------------+
double NormalizarPreco(double preco)
{
    if(tickSize == 0)
        return preco;
        
    return NormalizeDouble(MathRound(preco / tickSize) * tickSize, _Digits);
}



//+------------------------------------------------------------------+
//| Verifica gatilhos nos preços de abertura e fechamento             |
//+-------------------------------------------high-------------------+
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
             double tamanhoCandle = MathAbs(rates[1].high - rates[1].low);
              LogMsg("INFO: Gatilho acionado: " +
                     "Linha: "+ DoubleToString(linhas[i])+
                     "Tamanho do candle: "+ DoubleToString(tamanhoCandle)+
                     "Open: "+ DoubleToString(rates[1].open)+
                     "Close: "+ DoubleToString(rates[1].close), LOG_LEVEL_INFO); 
                     
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
    // Trava: só permite uma entrada por candle de gatilho
    if (ultimoCandleEntrada == rateGatilho.time) {
        LogMsg("Já houve entrada neste candle de gatilho, ignorando novo gatilho.", LOG_LEVEL_INFO);
        return;
    }
    // Bloqueio por locks de risco
    if (vTargetLockMeta || vTargetLockLoss || vTargetLockDrawdown) {
        LogMsg("ENTRADA BLOQUEADA: Algum lock de risco está ativo (Meta, Loss ou Drawdown)", LOG_LEVEL_INFO);
        return;
    }
    
    double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    
    LogMsg("DEBUG: StopLevel exigido pelo ativo: " + DoubleToString(stopLevel, _Digits), LOG_LEVEL_DEBUG);
    LogMsg("DEBUG: TickSize do ativo: " + DoubleToString(tickSize, _Digits), LOG_LEVEL_DEBUG);
    
    // Compra: fechamento acima da linha -> EXECUTA COMPRA
    if(rates[0].close > linhas[indice_linha] 
       && rateGatilho.high < SymbolInfoDouble(_Symbol, SYMBOL_BID) ){
        // Permite apenas uma ordem aberta ou pendente por vez
        if (has_open_position(MagicNumber) || has_open_order(MagicNumber)) {
            LogMsg("INFO: Já existe uma posição ou ordem pendente aberta. Não será aberta nova ordem de COMPRA.", LOG_LEVEL_INFO);
            return;
        }
        double takeProfit = EncontrarProximoNivelSuperior(linhas, indice_linha, rates[0].close); // TP acima
        if(takeProfit > 0)
        {
            double precoEntrada = rateGatilho.close;
            //double tamanhoCandle = MathAbs(rateGatilho.high - rateGatilho.low);
            double stop_calc = linhas[indice_linha] - (incrementoTickCurrent * (percentualStopLoss/100.0));
            double minDist = MathMax(stopLevel, tickSize * 2);
            double stop_loss = MathMin(roundPriceH9K(stop_calc, tickSize), precoEntrada - tickSize);
            if (stop_loss >= precoEntrada) stop_loss = precoEntrada - tickSize;
            if ((precoEntrada - stop_loss) < minDist)
                stop_loss = precoEntrada - minDist;
            LogMsg("DEBUG: (TESTE) Compra - entrada: " + DoubleToString(precoEntrada, _Digits) + " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits), LOG_LEVEL_DEBUG);
            LogMsg("DEBUG: Diferença SL: " + DoubleToString(MathAbs(precoEntrada - stop_loss), _Digits) + " Diferença TP: " + DoubleToString(MathAbs(takeProfit - precoEntrada), _Digits), LOG_LEVEL_DEBUG);
            
            // Validação para COMPRA
            LogMsg("DEBUG: Validação COMPRA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                   " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits), LOG_LEVEL_DEBUG);
            LogMsg("DEBUG: Condições - stop < entrada: " + (stop_loss < precoEntrada ? "SIM" : "NÃO"), LOG_LEVEL_DEBUG);
            LogMsg("DEBUG: Distância SL: " + DoubleToString(precoEntrada - stop_loss, _Digits) + ", Distância TP: " + DoubleToString(takeProfit - precoEntrada, _Digits), LOG_LEVEL_DEBUG);
            
            if(stop_loss < precoEntrada && takeProfit > precoEntrada &&
               (precoEntrada - stop_loss > stopLevel) && (takeProfit - precoEntrada > stopLevel)) {
                LogMsg("DEBUG: Executando COMPRA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits), LOG_LEVEL_DEBUG);
                if (ExecutarCompra(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), roundPriceH9K(takeProfit,tickSize))) {
                    ultimoCandleEntrada = rateGatilho.time;
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
        // Permite apenas uma ordem aberta ou pendente por vez
        if (has_open_position(MagicNumber) || has_open_order(MagicNumber)) {
            LogMsg("INFO: Já existe uma posição ou ordem pendente aberta. Não será aberta nova ordem de VENDA.", LOG_LEVEL_INFO);
            return;
        }
        double takeProfit = EncontrarProximoNivelInferior(linhas, indice_linha, rates[0].close); // TP abaixo
        if(takeProfit > 0)
        {
            double precoEntrada = rateGatilho.open;
            //double tamanhoCandle = MathAbs(rateGatilho.high - rateGatilho.low);
            double stop_calc = linhas[indice_linha] + (incrementoTickCurrent * (percentualStopLoss/100.0));
            double minDist = MathMax(stopLevel, tickSize * 2);
            double stop_loss = MathMax(roundPriceH9K(stop_calc, tickSize), precoEntrada + tickSize);
            if (stop_loss <= precoEntrada) stop_loss = precoEntrada + tickSize;
            if ((stop_loss - precoEntrada) < minDist)
                stop_loss = precoEntrada + minDist;
            LogMsg("DEBUG: (TESTE) Venda - entrada: " + DoubleToString(precoEntrada, _Digits) + " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits), LOG_LEVEL_DEBUG);
            LogMsg("DEBUG: Diferença SL: " + DoubleToString(MathAbs(precoEntrada - stop_loss), _Digits) + " Diferença TP: " + DoubleToString(MathAbs(takeProfit - precoEntrada), _Digits), LOG_LEVEL_DEBUG);
            
            // Validação para VENDA
            LogMsg("DEBUG: Validação VENDA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                   " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits), LOG_LEVEL_DEBUG);
            LogMsg("DEBUG: Condições - stop > entrada: " + (stop_loss > precoEntrada ? "SIM" : "NÃO"), LOG_LEVEL_DEBUG);
            LogMsg("DEBUG: Distância SL: " + DoubleToString(stop_loss - precoEntrada, _Digits) + ", Distância TP: " + DoubleToString(precoEntrada - takeProfit, _Digits), LOG_LEVEL_DEBUG);
            
            if(stop_loss > precoEntrada && takeProfit < precoEntrada &&
               (stop_loss - precoEntrada > stopLevel) && (precoEntrada - takeProfit > stopLevel)) {
                LogMsg("DEBUG: Executando VENDA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits), LOG_LEVEL_DEBUG);
                if (ExecutarVenda(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), roundPriceH9K(takeProfit,tickSize))) {
                    ultimoCandleEntrada = rateGatilho.time;
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
bool ExecutarCompra(double preco_entrada, double stop_loss, double take_profit)
{
    // Abre a ordem principal de compra
    bool order_sent = trade.Buy(Volume, _Symbol, preco_entrada, stop_loss, take_profit, EnumToString(orginSelect) + " : " + _Symbol);
        LogMsg("INFO: Ordem de COMPRA executada - Volume: " + DoubleToString(Volume, 2) +
               " SL: " + DoubleToString(stop_loss, _Digits) +
               " TP: " + DoubleToString(take_profit, _Digits), LOG_LEVEL_INFO);
        
    if(order_sent && !orderRejected(trade.ResultRetcode())) {
        waitForOrderExecution(preco_entrada, MagicNumber);
        ulong ticket = trade.ResultOrder();
        
        return true;
    }
    
    
    LogMsg("ERRO ao executar ordem de COMPRA: " + IntegerToString(trade.ResultRetcode()), LOG_LEVEL_ERROR);
    return false;
}

//+------------------------------------------------------------------+
//| Executa ordem de venda                                            |
//+------------------------------------------------------------------+
bool ExecutarVenda(double preco_entrada, double stop_loss, double take_profit){
    // Abre a ordem principal de venda
    bool order_sent = trade.Sell(Volume, _Symbol, preco_entrada, stop_loss, take_profit, EnumToString(orginSelect) + " : " + _Symbol);
        
        LogMsg("INFO: Ordem de VENDA executada - Volume: " + DoubleToString(Volume, 2) +
               " SL: " + DoubleToString(stop_loss, _Digits) +
               " TP: " + DoubleToString(take_profit, _Digits), LOG_LEVEL_INFO);
    
    if(order_sent && !orderRejected(trade.ResultRetcode())) {
        waitForOrderExecution(preco_entrada, MagicNumber);
        ulong ticket = trade.ResultOrder();
        return true;
    }
    
    LogMsg("ERRO: Error ao executar ordem de VENDA: " + IntegerToString(trade.ResultRetcode()), LOG_LEVEL_ERROR);
    return false;
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
    for(int j = indice_atual + 1; j < ArraySize(linhas); j++)
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
    for(int j = indice_atual - 1; j >= 0; j--)
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
    
    if (numPartes != 2)
    {
        LogMsg("Erro: Formato de horário inválido. Use HH:MM", LOG_LEVEL_ERROR);
        return -1;
    }
    
    int horas = (int)StringToInteger(partes[0]);
    int minutos = (int)StringToInteger(partes[1]);
    
    // Validar valores
    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59)
    {
        LogMsg("Erro: Horário inválido. Horas: 0-23, Minutos: 0-59", LOG_LEVEL_ERROR);
        return -1;
    }
    
    return horas * 60 + minutos;
}

//+------------------------------------------------------------------+
//| Função para fazer chamada HTTP para endpoint externo              |
//+------------------------------------------------------------------+
string FazerChamadaHTTP(string symbol, int nivel)
{
    string url = "http://127.0.0.1:8080/api/fonte-dados/" + symbol + "/" + IntegerToString(nivel)+"/" + EnumToString(orginSelect);
    
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
    string config = "{\"ativo\":\"" + symbol + "\",\"marcoZero\":121800,\"tamanhoCanal\":748,\"nivel\":" + DoubleToString(nivel) + "}";
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
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == magic) {
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
                    if(entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT) { // saída de posição
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
            Print("Ordem executada");
        } else if (lastOrderState == ORDER_STATE_CANCELED) {
            Print("Ordem cancelada");
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
        
    }
    break;
    }
}
