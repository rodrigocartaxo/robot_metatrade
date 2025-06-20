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


//--- input parameters
input group "Daytrade Window"
input ENUM_SIM_NAO i24h = nao; //Liga o modo 24h (forex)
input string iHoraIni  = "09:05:00"; //Hora inicio
input string iHoraFim  = "17:30:00"; //Hora fim
input string iHoraInterval1                   = "12:00"; //Hora Inicio Pausa
input string iHoraInterval2                   = "13:30"; //Hora Fim Pausa

// Parâmetros gerais
input group "=== Configurações Gerais ==="
input ENUM_TIMEFRAMES Periodo                 = PERIOD_M2;  // Período do Gráfico
input ENUM_CHANNEL_LEVEL NivelAtivo           = NIVEL_1;  // Nível do Canal a Exibir
input double   Volume                         = 10;       // Volume das Operações
input ENUM_SIM_NAO MostrarLogs                = sim;      // Mostrar logs detalhados
input ENUM_SIM_NAO AtivarInterval             = sim;      // Ativar Hora de pausa 
input int numeroLinhas                        =  25 ; //Numero de canais


input group "=== Configurações Canais ==="
input int      EspessuraLinha                 = 1;      // Espessura das linhas
input ENUM_LINE_STYLE EstiloLinha             = STYLE_SOLID;  // Estilo das linhas
input ENUM_SIM_NAO MostrarPreco               = sim;     // Mostrar preço nas linhas

// Parâmetros de Gerenciamento de Posição
input group "=== Gerenciamento de Posição ==="
input ENUM_SIM_NAO GerenciarPosicoesAtivado   = sim; // Ativar Gerenciamento de Posição
input int      PontosParaFechamentoParcial    = 50;  // Pontos para fechamento parcial
input double   PercentualFechamentoParcial    = 20.0; // Percentual a fechar por etapa
input int      NumeroMaximoFechamentosParciais= 5; // Número máximo de fechamentos parciais

// Parâmetros de Trailing Stop
input group "=== Trailing Stop ==="
input ENUM_SIM_NAO AtivarTrailingStop            = sim;   // Ativar Trailing Stop
input double   PercentualLucroParaAtivarTrailing = 50.0; // Percentual de lucro para ativar trailing stop
input int      NumeroMaximoFechamentoAtivaTP     = 4; // Número máximo de fechamentos parciais


input group "=== ATR Settings === "
input int                   iATRPeriod            = 14;                   // ATR Period
input ENUM_TIMEFRAMES       iATRTimeFrame         = PERIOD_M5;           // ATR Timeframe


input group "=== Risk Management ==="
input ENUM_SIM_NAO riskManagement            = sim;   // Ativar Risk Management
input int    iDailyTarget                    = 10000;    // Meta de ganho 
input int    iLossTarget                     = 500;     // Loss máximo 
input double iDDTrigger                      = 300;     // Valor para ativar o drawdown
input double iDrawDown                       = 80;       // Percentual do valor para fechar posição


// Variáveis globais
double ultimoPreco,vMaxProfit;
string prefixoObjeto = "PriceChannel_";
double tickSize; // Tamanho do tick do ativo
double incrementoTickCurrent = 0;
MqlRates rates[];
MqlRates rateGatilho;

// Variáveis globais de trading
CTrade trade;
bool posicaoAberta = false;
ulong posicaoTicket = 0;

// Variáveis globais de trailing
bool primeiroAlvoAtingido = false;
double nivelTrailingStop = 0;
double takeProfitFinal = 0;
bool trailingStopAtivado = false; // Flag para controlar se o trailing stop está ativo
double stopLossAtual = 0; // Armazena o stop loss atual da posição

double dataATR[];
int handleAtr;

bool vTPTrigger = false;
bool vTargetLock = false;
bool vDDTriggerActive = false;

double l_result = 0.0;

ulong MagicNumber = 0.0; 

MyMagicNumber myMagicNumber;

// Variáveis de gerenciamento de posição
int fechoParcialContador = 0;
double volumeOriginal = 0;

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

//+------------------------------------------------------------------+
//| Função para log                                                    |
//+------------------------------------------------------------------+
void LogInfo(string mensagem)
{
    if(MostrarLogs == sim)
    {
        Print(mensagem);
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
        Print("Este EA só pode ser executado em contas em DEMO.");
        return INIT_FAILED;
    }
    
    MagicNumber = CalcularMagicNumber(MQLInfoString(MQL_PROGRAM_NAME), _Symbol); 
    
    // Configurar os níveis
    ArrayResize(niveis, 3);
    
    // Carregar configuração apenas do nível selecionado da API
    ConfiguracaoCanal config;
    int nivelSelecionado = (int)NivelAtivo;
    
    if(!CarregarConfiguracaoAPI(_Symbol, nivelSelecionado, config))
    {
        LogInfo("ERRO: Falha ao carregar configuração do Nível " + IntegerToString(nivelSelecionado) + " da API");
        return INIT_FAILED;
    }
    
    // Configurar apenas o nível selecionado
    int nivelIndex = nivelSelecionado - 1;
    if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis))
    {
        niveis[nivelIndex].precoBase = config.marcoZero;
        niveis[nivelIndex].incrementoTick = config.tamanhoCanal;
        niveis[nivelIndex].nivel = config.nivel;
        
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
        
        LogInfo("DEBUG: Nível " + IntegerToString(nivelSelecionado) + " configurado - Base: " + 
                DoubleToString(niveis[nivelIndex].precoBase, _Digits) + 
                " Incremento: " + DoubleToString(niveis[nivelIndex].incrementoTick, _Digits) +
                " Nível: " + IntegerToString(niveis[nivelIndex].nivel));
    }
    else
    {
        LogInfo("ERRO: Nível inválido selecionado!");
        return INIT_FAILED;
    }
    
    // Obter o tamanho do tick do ativo
    tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize == 0){
        Print("ERRO: Falha ao obter o tamanho do tick do ativo!");
        return INIT_FAILED;
    }
    
    LogInfo("Tamanho do tick do ativo " + _Symbol + ": " + DoubleToString(tickSize, _Digits));
    
    handleAtr = iATR(_Symbol, iATRTimeFrame, iATRPeriod);
    
    if (handleAtr==INVALID_HANDLE){
        Print("FAILED TO CREATE HANDLE OF THE iATR INDICATOR. REVERTING NOW");
        return INIT_FAILED;
    }
   
    // Configurar array de rates
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(dataATR,true);
    vMaxProfit = 0;
    
    // Limpar objetos antigos
    LimparObjetos();
    
    // Criar apenas o nível selecionado
    if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis))
    {
        LogInfo("Configurando Nível " + IntegerToString(nivelSelecionado));
        LogInfo("Preço Base: " + DoubleToString(niveis[nivelIndex].precoBase, _Digits));
        LogInfo("Incremento: " + DoubleToString(niveis[nivelIndex].incrementoTick, 0));
        incrementoTickCurrent = niveis[nivelIndex].incrementoTick;
        CriarLinhasNivel(niveis[nivelIndex]);
    }
    else {
        Print("ERRO: Nível inválido selecionado!");
        return INIT_FAILED;
    }
    
    // Forçar redesenho inicial
    ChartSetInteger(0, CHART_AUTOSCROLL, true);
    ChartSetInteger(0, CHART_SHIFT, true);
    ChartRedraw(0);
    
    // Configurações de trading
    trade.SetDeviationInPoints(10); // Desvio máximo do preço
    trade.SetTypeFilling(ORDER_FILLING_RETURN); // Tipo de preenchimento
    trade.SetExpertMagicNumber(MagicNumber); // Número mágico do EA
    trade.LogLevel(LOG_LEVEL_ALL); // Nível de log
    trade.SetAsyncMode(false); // Modo síncrono para garantir execução correta
    
    if((DailyResult(MagicNumber) + OpenResult(MagicNumber)) <= 0.95*iDailyTarget) {
        vTargetLock = false;
    }
    
    LogInfo(StringFormat("[%d] Inicializado com sucesso!", MagicNumber));
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Fechar posições abertas se houver
    if(HasPosition(MagicNumber)>0)
    {
        trade.PositionClose(posicaoTicket);
        LogInfo("Posição fechada na finalização do EA");
    }
    
    // Resetar variáveis de trailing stop
    trailingStopAtivado = false;
    stopLossAtual = 0;
    
     if (handleAtr!= INVALID_HANDLE)
        IndicatorRelease(handleAtr);
    
    // Limpar todos os objetos, incluindo triggers
    ObjectsDeleteAll(0, prefixoObjeto);
    ChartRedraw(0);
    LogInfo("EA finalizado. Motivo: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick(){
    
    int open_positions = HasPosition(MagicNumber);
    int open_orders    = OpenOrdersCount(MagicNumber);
    
    l_result = DailyResult(MagicNumber) + OpenResult(MagicNumber);
    
    
    if (!i24h && !allowed_by_hour(iHoraIni, iHoraFim)) {
        closeAllPositions(trade, MagicNumber);
        closeAllOpenOrders(trade, MagicNumber);        
        vTargetLock = false;
        vDDTriggerActive = false;
        return;
    }
    
    if(AtivarInterval == sim){
      if(EstaNoHorarioDePausa(iHoraInterval1,iHoraInterval2)){
         if (isNewBar(Periodo)) {LogInfo("INFO: Hora de intervalo ativada ");};
         return;
      }  
    }
    
    if (riskManagement == sim){
         GerenciarRisk();
     }   
       
    // Obter dados do último candle
    if(CopyRates(_Symbol, Periodo, 0, 3, rates) <= 0)
    {
        LogInfo("ERRO: Falha ao copiar dados do último candle");
        return;
    }
    
    ArraySetAsSeries(rates, true);
    
    
    // Verificar apenas o nível selecionado
    int nivelIndex = (int)NivelAtivo - 1;
    if(nivelIndex >= 0 && nivelIndex < ArraySize(niveis)){
        double linhasPreco[];
        CalcularLinhasPreco(linhasPreco, niveis[nivelIndex]);
        AtualizarLinhasNivel(linhasPreco, niveis[nivelIndex]);
        
        // Verificar gatilhos
        VerificarGatilhos(linhasPreco);
        ChartRedraw(0);
    }
    
    // Gerenciar posições abertas
    if(GerenciarPosicoesAtivado == sim){
        GerenciarPosicoesAbertas();
    }
    
    // Gerencia o trailing stop para posições abertas
    if(AtivarTrailingStop == sim){
      GerenciarTrailingStop();
    }
    
}

void GerenciarRisk(){
   
   if (isNewBar(Periodo)){ LogInfo(StringFormat("[%d] Result of day at moment (%.2f / %.2f).", MagicNumber, iDailyTarget, l_result));}
   
   if(vTargetLock == true) {
        if (isNewBar(Periodo)){ LogInfo(StringFormat("[%d] DailyTarget achieved (%.2f / %.2f).", MagicNumber, iDailyTarget, l_result));}
        closeAllOpenOrders(trade, MagicNumber);
        closeAllPositions(trade, MagicNumber);        
        return;
    }    
    
    if(l_result >= iDDTrigger) {
        if(!vDDTriggerActive) PrintFormat("[%d] Drawdown trigger activated (%.2f).", MagicNumber, l_result);
        vDDTriggerActive = true;
        if (vMaxProfit < l_result) vMaxProfit = l_result;        
    }
    
    if(vDDTriggerActive && l_result <= (1 - iDrawDown/100)*vMaxProfit) {
        PrintFormat("[%d] Drawdown %.2f achieved (%.2f / %.2f).", MagicNumber, iDrawDown, vMaxProfit, l_result);
        closeAllOpenOrders(trade, MagicNumber);
        closeAllPositions(trade, MagicNumber); 
        vTargetLock = true;
        return;
    }

    if(l_result >= iDailyTarget) {
        PrintFormat("[%d] DailyTarget achieved (%.2f / %.2f).", MagicNumber, iDailyTarget, l_result);
        closeAllOpenOrders(trade, MagicNumber);
        closeAllPositions(trade, MagicNumber);        
        vTargetLock = true;
        return;
    }
    
    if((DailyResult(MagicNumber) + OpenResult(MagicNumber)) <= -1 * iLossTarget) {
        PrintFormat("[%d] LossTarge achieved  %.2f.", MagicNumber, iLossTarget);
        closeAllOpenOrders(trade, MagicNumber);
        closeAllPositions(trade, MagicNumber);        
        vTargetLock = true;
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
    double linhasPreco[];
    CalcularLinhasPreco(linhasPreco, nivel);
    
    datetime tempo = TimeCurrent();
    double pontoPip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    LogInfo("DEBUG: Criando linhas para nível - Base: " + DoubleToString(nivel.precoBase, _Digits) + 
            " Incremento: " + DoubleToString(nivel.incrementoTick, _Digits) +  " Nivel : "+ IntegerToString(nivel.nivel)  );
    
    for(int i = 0; i < ArraySize(linhasPreco); i++)
    {
        string nomeObjeto = prefixoObjeto + nivel.prefixo + IntegerToString(i);
        
        if(!ObjectCreate(0, nomeObjeto, OBJ_HLINE, 0, 0, linhasPreco[i]))
        {
            Print("ERRO: Falha ao criar linha ", nomeObjeto);
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
                Print("ERRO: Falha ao criar texto ", nomeTexto);
                continue;
            }
            
            ObjectSetString(0, nomeTexto, OBJPROP_TEXT, nivel.prefixo + DoubleToString(linhasPreco[i], _Digits));
            ObjectSetInteger(0, nomeTexto, OBJPROP_COLOR, ColorBrighten(nivel.corBase, 20 * i));
            ObjectSetInteger(0, nomeTexto, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
            ObjectSetInteger(0, nomeTexto, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, nomeTexto, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, nomeTexto, OBJPROP_FONTSIZE, 10);
        }
        
        LogInfo("DEBUG: Linha criada - Nome: " + nomeObjeto + " Preço: " + DoubleToString(linhasPreco[i], _Digits));
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Atualiza as linhas de um nível específico                         |
//+------------------------------------------------------------------+
void AtualizarLinhasNivel(double &linhasPreco[], NivelCanal &nivel)
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
    //LogInfo("Objetos removidos: " + IntegerToString(count));
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
//| Calcula o Average True Range (ATR)                                |
//+------------------------------------------------------------------+
double refreshATR( ){
    
    if (CopyBuffer(handleAtr, 0, 0, 3, dataATR) < 3) {
      LogInfo(StringFormat("ERROR:copying ATR buffer for ", _Symbol));
      return 0;
   }
   ArraySetAsSeries(dataATR, true);
    
   return dataATR[0];
}
//+------------------------------------------------------------------+
//| Cacula stop loss                                                 |
//+------------------------------------------------------------------+
double calculaStopLoss(string tipo, int indice, double &linhas[]){
    double price_step = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double tamanhoCandle = MathAbs(rateGatilho.high - rateGatilho.low);
    double stop = 0.0;
    
    if (tipo == "compra" ){
        double precoEntrada = rateGatilho.close;
        stop = roundPriceH9K(precoEntrada + (tamanhoCandle * 1.75), price_step);
        LogInfo("DEBUG: Compra (INVERTIDO) - entrada: " + DoubleToString(precoEntrada, _Digits) + 
               " stop: " + DoubleToString(stop, _Digits) + 
               " diferença: " + DoubleToString(stop - precoEntrada, _Digits));
    } else if (tipo == "venda" ){
        double precoEntrada = rateGatilho.open;
        stop = roundPriceH9K(precoEntrada - (tamanhoCandle * 1.75), price_step);
        LogInfo("DEBUG: Venda (INVERTIDO) - entrada: " + DoubleToString(precoEntrada, _Digits) + 
               " stop: " + DoubleToString(stop, _Digits) + 
               " diferença: " + DoubleToString(precoEntrada - stop, _Digits));
    }
    
    LogInfo("DEBUG: Stop loss calculado para " + tipo + " - entrada: " + DoubleToString((tipo == "compra") ? rateGatilho.close : rateGatilho.open, _Digits) + " stop: " + DoubleToString(stop, _Digits));
    return stop;
}

//+------------------------------------------------------------------+
//| Verifica gatilhos nos preços de abertura e fechamento             |
//+-------------------------------------------high-------------------+
void VerificarGatilhos(double &linhas[]){

    

    // Verificar se o candle atravessa alguma linha
    for(int i = 0; i < ArraySize(linhas); i++)
    {
        // Verifica se o candle atravessou a linha (abertura abaixo e fechamento acima OU vice-versa)
        if((rates[1].open < linhas[i] && rates[1].close > linhas[i]) || 
           (rates[1].open > linhas[i] && rates[1].close < linhas[i])){
             rateGatilho = rates[1];
             double tamanhoCandle = MathAbs(rates[1].high - rates[1].low);
              LogInfo("INFO: Gatilho acionado: " +
                     "Linha: "+ DoubleToString(linhas[i])+
                     "Tamanho do candle: "+ DoubleToString(tamanhoCandle)+
                     "Open: "+ DoubleToString(rates[1].open)+
                     "Close: "+ DoubleToString(rates[1].close)); 
                     
            VerificarEntradas(linhas, i);
            break;
        };
    }
}

//+------------------------------------------------------------------+
//| Verifica e executa entradas                                        |
//+------------------------------------------------------------------+
void VerificarEntradas(double &linhas[], int indice_linha){
    
    
    double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    
    LogInfo("DEBUG: StopLevel exigido pelo ativo: " + DoubleToString(stopLevel, _Digits));
    LogInfo("DEBUG: TickSize do ativo: " + DoubleToString(tickSize, _Digits));
    
    // Compra: fechamento acima da linha -> EXECUTA COMPRA
    if(rates[0].close > rateGatilho.close && rates[0].close > linhas[indice_linha])
    {
        // Permite apenas uma ordem aberta ou pendente por vez
        if (has_open_position(MagicNumber) || has_open_order(MagicNumber)) {
            LogInfo("INFO: Já existe uma posição ou ordem pendente aberta. Não será aberta nova ordem de COMPRA.");
            return;
        }
        double takeProfit = EncontrarProximoNivelSuperior(linhas, indice_linha, rates[0].close); // TP acima
        if(takeProfit > 0)
        {
            double precoEntrada = rateGatilho.close;
            double tamanhoCandle = MathAbs(rateGatilho.high - rateGatilho.low);
            double stop_calc = precoEntrada - (tamanhoCandle * 0.75);
            double minDist = MathMax(stopLevel, tickSize * 4);
            double stop_loss = MathMin(roundPriceH9K(stop_calc, tickSize), precoEntrada - tickSize);
            if (stop_loss >= precoEntrada) stop_loss = precoEntrada - tickSize;
            if ((precoEntrada - stop_loss) < minDist)
                stop_loss = precoEntrada - minDist;
            LogInfo("DEBUG: (TESTE) Compra - entrada: " + DoubleToString(precoEntrada, _Digits) + " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits));
            LogInfo("DEBUG: Diferença SL: " + DoubleToString(MathAbs(precoEntrada - stop_loss), _Digits) + " Diferença TP: " + DoubleToString(MathAbs(takeProfit - precoEntrada), _Digits));
            
            // Validação para COMPRA
            LogInfo("DEBUG: Validação COMPRA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                   " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits));
            LogInfo("DEBUG: Condições - stop < entrada: " + (stop_loss < precoEntrada ? "SIM" : "NÃO") + 
                   " tp > entrada: " + (takeProfit > precoEntrada ? "SIM" : "NÃO"));
            LogInfo("DEBUG: Distância SL: " + DoubleToString(precoEntrada - stop_loss, _Digits) + ", Distância TP: " + DoubleToString(takeProfit - precoEntrada, _Digits));
            
            if(stop_loss < precoEntrada && takeProfit > precoEntrada &&
               (precoEntrada - stop_loss > stopLevel) && (takeProfit - precoEntrada > stopLevel)) {
                LogInfo("DEBUG: Executando COMPRA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits));
                ExecutarCompra(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), roundPriceH9K(takeProfit,tickSize));
            } else {
                LogInfo("ERRO: Preços inválidos para COMPRA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits) +
                       " (verifique se SL/TP respeitam o stop level mínimo: " + DoubleToString(stopLevel, _Digits) + ")");
            }
        }
    }
    // Venda: fechamento abaixo da linha -> EXECUTA VENDA
    else if(rates[0].close < rateGatilho.open && rates[0].close < linhas[indice_linha]){ 
        // Permite apenas uma ordem aberta ou pendente por vez
        if (has_open_position(MagicNumber) || has_open_order(MagicNumber)) {
            LogInfo("INFO: Já existe uma posição ou ordem pendente aberta. Não será aberta nova ordem de VENDA.");
            return;
        }
        double takeProfit = EncontrarProximoNivelInferior(linhas, indice_linha, rates[0].close); // TP abaixo
        if(takeProfit > 0)
        {
            double precoEntrada = rateGatilho.open;
            double tamanhoCandle = MathAbs(rateGatilho.high - rateGatilho.low);
            double stop_calc = precoEntrada + (tamanhoCandle * 0.75);
            double minDist = MathMax(stopLevel, tickSize * 4);
            double stop_loss = MathMax(roundPriceH9K(stop_calc, tickSize), precoEntrada + tickSize);
            if (stop_loss <= precoEntrada) stop_loss = precoEntrada + tickSize;
            if ((stop_loss - precoEntrada) < minDist)
                stop_loss = precoEntrada + minDist;
            LogInfo("DEBUG: (TESTE) Venda - entrada: " + DoubleToString(precoEntrada, _Digits) + " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits));
            LogInfo("DEBUG: Diferença SL: " + DoubleToString(MathAbs(precoEntrada - stop_loss), _Digits) + " Diferença TP: " + DoubleToString(MathAbs(takeProfit - precoEntrada), _Digits));
            
            // Validação para VENDA
            LogInfo("DEBUG: Validação VENDA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                   " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits));
            LogInfo("DEBUG: Condições - stop > entrada: " + (stop_loss > precoEntrada ? "SIM" : "NÃO") + 
                   " tp < entrada: " + (takeProfit < precoEntrada ? "SIM" : "NÃO"));
            LogInfo("DEBUG: Distância SL: " + DoubleToString(stop_loss - precoEntrada, _Digits) + ", Distância TP: " + DoubleToString(precoEntrada - takeProfit, _Digits));
            
            if(stop_loss > precoEntrada && takeProfit < precoEntrada &&
               (stop_loss - precoEntrada > stopLevel) && (precoEntrada - takeProfit > stopLevel)) {
                LogInfo("DEBUG: Executando VENDA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits));
                ExecutarVenda(roundPriceH9K(precoEntrada,tickSize), roundPriceH9K(stop_loss,tickSize), roundPriceH9K(takeProfit,tickSize));
            } else {
                LogInfo("ERRO: Preços inválidos para VENDA - entrada: " + DoubleToString(precoEntrada, _Digits) + 
                       " stop: " + DoubleToString(stop_loss, _Digits) + " tp: " + DoubleToString(takeProfit, _Digits) +
                       " (verifique se SL/TP respeitam o stop level mínimo: " + DoubleToString(stopLevel, _Digits) + ")");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Executa ordem de compra                                            |
//+------------------------------------------------------------------+
bool ExecutarCompra(double preco_entrada, double stop_loss, double take_profit)
{
  
    // Primeiro faz a ordem com volume dobrado e sem take profit
    if(trade.Buy(Volume , _Symbol,preco_entrada,  stop_loss, take_profit,DoubleToString(MagicNumber))){
       
        posicaoAberta = true;
        posicaoTicket = trade.ResultOrder();
        volumeOriginal = Volume;
        fechoParcialContador = 0;
        takeProfitFinal = take_profit; // Armazena o take profit final
        stopLossAtual = stop_loss; // Armazena o stop loss inicial
        
        LogInfo("INFO: Ordem de COMPRA executada - Volume: " + DoubleToString(Volume , 2) + 
                 " Sl: " + DoubleToString(stop_loss, _Digits)+
                  " TP: " + DoubleToString(take_profit, _Digits) ); 
       return true;
        
    }
    LogInfo("ERRO ao executar ordem de COMPRA: " + IntegerToString(trade.ResultRetcode()));
    return false;
}

//+------------------------------------------------------------------+
//| Executa ordem de venda                                            |
//+------------------------------------------------------------------+
bool ExecutarVenda(double preco_entrada, double stop_loss, double take_profit)
{
    // Primeiro faz a ordem com volume dobrado e sem take profit
    if(trade.Sell(Volume ,  _Symbol, preco_entrada ,stop_loss,take_profit,DoubleToString(MagicNumber))){
        posicaoAberta = true;
        posicaoTicket = trade.ResultOrder();
        volumeOriginal = Volume;
        fechoParcialContador = 0;
        takeProfitFinal = take_profit; // Armazena o take profit final
        stopLossAtual = stop_loss; // Armazena o stop loss inicial
        
        LogInfo("INFO: Ordem de VENDA executada - Volume: " + DoubleToString(Volume , 2) + 
                   " SL: " + DoubleToString(stop_loss, _Digits)+
                   " TP: " + DoubleToString(take_profit, _Digits));  
                           
       return true;
    }
    
    LogInfo("ERRO: Error ao executar ordem de VENDA: " + IntegerToString(trade.ResultRetcode()));
    return false;
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
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
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
                        LogInfo("DEBUG: Initial volumeToClose: " + DoubleToString(volumeToClose, 8) + ", currentVolume: " + 
                         DoubleToString(currentVolume, 8) + ", PercentualFechamentoParcial: " + 
                         DoubleToString(PercentualFechamentoParcial, 2));

                        // Normalize volume to ensure it's valid
                        volumeToClose = NormalizeDouble(volumeToClose, 2); // Assuming 2 decimal places for volume
                        LogInfo("DEBUG: volumeToClose after NormalizeDouble: " + DoubleToString(volumeToClose, 8));
                        
                        // Ensure volume is at least minimum allowed volume and a multiple of step
                        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                        double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                        LogInfo("DEBUG: minVolume: " + DoubleToString(minVolume, 8) + ", volumeStep: " + DoubleToString(volumeStep, 8));
                        
                        if(volumeToClose < minVolume)
                        {
                            volumeToClose = minVolume;
                            LogInfo("DEBUG: volumeToClose adjusted to minVolume: " + DoubleToString(volumeToClose, 8));
                        }
                        
                        // Adjust volume to be a multiple of volumeStep
                        volumeToClose = MathRound(volumeToClose / volumeStep) * volumeStep;
                        LogInfo("DEBUG: volumeToClose after adjusting for volumeStep: " + DoubleToString(volumeToClose, 8));

                        // Ensure calculated volume does not exceed current position volume
                        if (volumeToClose > currentVolume) {
                            volumeToClose = currentVolume;
                            LogInfo("DEBUG: volumeToClose adjusted to not exceed currentVolume: " + DoubleToString(volumeToClose, 8));
                        }

                        if(trade.PositionClosePartial(ticket, volumeToClose))
                        {
                            fechoParcialContador++;
                            LogInfo("INFO: Fechamento parcial: " + DoubleToString(volumeToClose, 2) + " a " + DoubleToString(currentPrice, _Digits) + ". Etapa: " + IntegerToString(fechoParcialContador));
                        }
                        else
                        {
                            LogInfo("ERRO: Falha ao fechar parcial da posição " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode()));
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Gerencia o trailing stop para posições abertas                    |
//+------------------------------------------------------------------+
void GerenciarTrailingStop()
{
     if (!HasPosition(MagicNumber)>0)
        return;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = 0;
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double currentSL = PositionGetDouble(POSITION_SL); // Current Stop Loss of the position

                if(type == POSITION_TYPE_BUY)
                {
                    currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                }
                else if(type == POSITION_TYPE_SELL)
                {
                    currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
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
                
                double profitPercentage = (profitPoints * _Point / openPrice) * 100;
               

                // Activation conditions
                if(!trailingStopAtivado &&((fechoParcialContador >= NumeroMaximoFechamentoAtivaTP || profitPercentage >= PercentualLucroParaAtivarTrailing)))
                {
                    trailingStopAtivado = true;
                    LogInfo("Trailing Stop Ativado! Profit Percentage: " + DoubleToString(profitPercentage, 2) + "%, Partial closes: " + IntegerToString(fechoParcialContador));
                }

                // Trailing logic
                if(trailingStopAtivado)
                {
                  
                    double atr = refreshATR(); // ATR of the previous candle
                    
                    if(atr == 0) return; // Error in ATR calculation

                    double newSL = 0;
                    if(type == POSITION_TYPE_BUY)
                    {
                        newSL = NormalizarPreco(currentPrice - atr);
                        if(newSL > stopLossAtual) // Only move SL up for BUY
                        {
                            stopLossAtual = NormalizarPreco(newSL);
                            if(trade.PositionModify(ticket, stopLossAtual, takeProfitFinal))
                            {
                                LogInfo("Trailing Stop BUY ajustado para: " + DoubleToString(stopLossAtual, _Digits));
                            }
                            else
                            {
                                LogInfo("ERRO: Falha ao ajustar Trailing Stop BUY: " + IntegerToString(trade.ResultRetcode()));
                            }
                        }
                    }
                    else if(type == POSITION_TYPE_SELL)
                    {
                        newSL = NormalizarPreco(currentPrice + atr);
                        if(newSL < stopLossAtual) // Only move SL down for SELL
                        {
                            stopLossAtual = NormalizarPreco(newSL);
                            if(trade.PositionModify(ticket, stopLossAtual, takeProfitFinal))
                            {
                                LogInfo("Trailing Stop SELL ajustado para: " + DoubleToString(stopLossAtual, _Digits));
                            }
                            else
                            {
                                LogInfo("ERRO: Falha ao ajustar Trailing Stop SELL: " + IntegerToString(trade.ResultRetcode()));
                            }
                        }
                    }
                }
            }
        }
    }
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
        Print("Erro: Formato de horário inválido. Use HH:MM");
        return -1;
    }
    
    int horas = (int)StringToInteger(partes[0]);
    int minutos = (int)StringToInteger(partes[1]);
    
    // Validar valores
    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59)
    {
        Print("Erro: Horário inválido. Horas: 0-23, Minutos: 0-59");
        return -1;
    }
    
    return horas * 60 + minutos;
}

//+------------------------------------------------------------------+
//| Função para fazer chamada HTTP para endpoint externo              |
//+------------------------------------------------------------------+
string FazerChamadaHTTP(string symbol, int nivel)
{
    string url = "http://127.0.0.1:8080/api/fonte-dados/" + symbol + "/" + IntegerToString(nivel);
    
    LogInfo("DEBUG: Fazendo chamada HTTP para: " + url);
    
    // Array para armazenar os dados da resposta
    uchar post_data[];
    uchar result_data[];
    string headers;
    
    // Faz a requisição HTTP
    int result = WebRequest("GET", url, headers, 5000, post_data, result_data, headers);
    
    if(result == 200) // Sucesso
    {
        string response = CharArrayToString(result_data);
        LogInfo("DEBUG: Resposta HTTP recebida: " + response);
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
        
        LogInfo("ERRO: Falha na chamada HTTP. Código: " + IntegerToString(result) + " - " + errorMsg);
        LogInfo("INFO: Usando configuração padrão como fallback");
        return CriarConfiguracaoPadrao(symbol, nivel);
    }
}

//+------------------------------------------------------------------+
//| Função para criar configuração padrão quando API não está disponível |
//+------------------------------------------------------------------+
string CriarConfiguracaoPadrao(string symbol, int nivel)
{
    string config = "{\"ativo\":\"" + symbol + "\",\"marcoZero\":121800,\"tamanhoCanal\":748,\"nivel\":" + DoubleToString(nivel) + "}";
    LogInfo("DEBUG: Configuração padrão criada para nível " + IntegerToString(nivel) + ": " + config);
    return config;
}

//+------------------------------------------------------------------+
//| Função para processar resposta JSON da API                        |
//+------------------------------------------------------------------+
bool ProcessarRespostaAPI(string response, ConfiguracaoCanal &config)
{
    if(StringLen(response) == 0)
    {
        LogInfo("ERRO: Resposta vazia da API");
        return false;
    }
    
    // Remove espaços e quebras de linha
    StringTrimLeft(response);
    StringTrimRight(response);
    
    LogInfo("DEBUG: Processando resposta JSON: " + response);
    
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
        
        LogInfo("Configuração carregada com sucesso da API:");
        LogInfo("Ativo: " + config.ativo);
        LogInfo("Marco Zero: " + DoubleToString(config.marcoZero, _Digits));
        LogInfo("Tamanho Canal: " + DoubleToString(config.tamanhoCanal, _Digits));
        LogInfo("Nível: " + IntegerToString(config.nivel));
        
        return true;
    }
    
    LogInfo("ERRO: Formato JSON inválido na resposta da API");
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