//+------------------------------------------------------------------+
//|                                       Robô_Estocastico+Media.mq5 |
//|                             Copyright 2025, No Risk No Gain LTDA.|
//|                                   https://www.norisknogain.com.br|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, No Risk No Gain Ltda."
#property link      "https://www.norisknogain.com.br"
#property version   "1.00"
#property description "BOT ESTOCASTICO+MÉDIA"


#include <Trade\SymbolInfo.mqh>
CSymbolInfo m_symbol;                     // Objeto de informação de símbolo

#include <Trade\Trade.mqh>
CTrade m_trade;

#include <Trade\PositionInfo.mqh>
CPositionInfo m_position;

//+------------------------------------------------------------------+
//| ENUMERADOR                                                       |
//+------------------------------------------------------------------+
  
  enum ENUM_SIM_NAO
  {
    sim,  // Sim
    nao   // Não
  };


//+------------------------------------------------------------------+
//|   INPUTS                                                         |
//+------------------------------------------------------------------+
input int                                    magic_number = 2;                   // NÚMERO MÁGICO

sinput string s3; //--------------CONFIGURAÇÕES GERAIS-----------------
input ENUM_TIMEFRAMES                       tempo_grafico = PERIOD_CURRENT;      // Tempo Gráfico
input ENUM_APPLIED_PRICE                    preco = PRICE_CLOSE;                 // Preco aplicado 
input ENUM_SIM_NAO                          conversaoPoints = nao;               // Converter para Points  

input double                                num_lots = 1;                        // Número de lotes
input double                                takeProfit = 1000;                   // Take Profit
input double                                stopLoss = 1000;                     // Stop Loss


//---👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇
sinput string s4; //--------------PARÂMETROS ESTOCÁSTICO-----------------
input int                                    NivelSup = 80;                      // Nível Superior   
input int                                    NivelInf = 20;                      // Nível Inferior
input int                                    PeriodoK = 5;                       // Periodo K
input int                                    PeriodoD = 3;                       // Periodo D
input int                                    Suavizacao = 3;                     // Suavização
input ENUM_MA_METHOD                         TipoSuavizacao=MODE_EMA;            // Tipo Média
input ENUM_STO_PRICE                         PrecoCalculoSto=STO_LOWHIGH;        // Cálculo baseado em:      

sinput string s5; //--------------PARÂMETROS MÉDIA MÓVEL-----------------
input double                                 distMaxPreco = 1500;                 // Distância Máxima do Preço até a média
input int                                    PeriodoMedia = 100;                 // Periodo Media
input ENUM_MA_METHOD                         TipoMedia = MODE_SMA;               // Tipo Média

//---👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆


sinput string s6; //--------------DEFINIÇÃO DE HORÁRIOS OPERACIONAIS-----------------
input string                                  hora_inicio = "09:00";             // Horário de Início das Entradas 
input string                                     hora_fim = "16:30";             // Horário de Encerramento das Entradas
input string                                 hora_zeragem = "17:00";             // Horário de Zeragem


//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS INDICADORES                                    |
//+------------------------------------------------------------------+


bool posicaoAberta=false;
bool candle_operado=false;
bool sinalC=false;
bool sinalV=false;

//---👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇
int handleMedia;
int handleStoch;
double BufferSinal[];
double BufferStoch[];
double BufferMedia[];
double distanciaPreco;



//---👆👆👆👆👆👆👆👆👆👆👆👆👆👆

string hoje = "";
datetime hora_atual = 0;

double tpcN=0; 
double slcN=0; 

double tpvN=0; 
double slvN=0; 

//+------------------------------------------------------------------+
//|  VARIÁVEIS PARA AS FUNÇÕES                                       |
//+------------------------------------------------------------------+

MqlTick tick;
MqlRates vela[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  
//--- Reseta o ultimo erro
  
  ResetLastError();
  
//--- Atualiza dados do simbolo
  
   m_symbol.Name(_Symbol);
   m_symbol.Refresh();



//---👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇
//--- Atribuição de variáveis
   
   handleMedia = iMA(_Symbol, tempo_grafico, PeriodoMedia, 0, TipoMedia, preco);
   if(handleMedia == INVALID_HANDLE) {Print("Erro ao criar o indicador Média."); return(INIT_FAILED);}
   
   handleStoch = iStochastic(_Symbol, tempo_grafico, PeriodoK, PeriodoD, Suavizacao, TipoSuavizacao, PrecoCalculoSto);
   if(handleStoch == INVALID_HANDLE) {Print("Erro ao criar o indicador Estocástico."); return(INIT_FAILED);}
   
   
   
//--- Carrega o indicador no gráfico
  
   ChartIndicatorAdd(0, 0, handleMedia);
   ChartIndicatorAdd(0, 1, handleStoch);
   
//---👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆   
 
//--- Carrega no grafico o tempo gráfico parametrizado no robô
   ChartSetSymbolPeriod(0, _Symbol, tempo_grafico);   

//--- FILLING DAS ORDENS, SLIPPAGE E OUTROS VALORES    
                
  m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
  m_trade.SetAsyncMode(false);
  m_trade.SetExpertMagicNumber(magic_number);
  m_trade.SetDeviationInPoints(25);  
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  
//---👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇
//---ALTERAR OS HANDLES E BUFFER DOS INDICADORES
   IndicatorRelease(handleMedia);
   IndicatorRelease(handleStoch);
   
   ArrayFree(BufferMedia);
   ArrayFree(BufferSinal);
   ArrayFree(BufferStoch);
//---👆👆👆👆👆👆👆👆👆👆👆👆👆👆     
   RemoveIndicadores();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
//--- Reseta o ultimo erro
  
    ResetLastError();
   
//--- Atualiza os dados so ativo

   if(!m_symbol.RefreshRates())
      return;
          
//--- copia um vetor de dados tamanho 5 para o vetor do buffer

//--- ALTERAR A CÓPIA DOS BUFFERS DOS INDICADORES
//---👇👇👇👇👇👇👇👇👇👇👇👇👇   👇👇👇👇👇👇👇👇👇👇👇👇👇   
   CopyBuffer(handleMedia, 0, 0, 4, BufferMedia);
   CopyBuffer(handleStoch, 1, 0, 4, BufferSinal);
   CopyBuffer(handleStoch, 0, 0, 4, BufferStoch);
   
  // Print("media: ", BufferMedia[0]);
   
//---Ordena os valores de dados   
   
   ArraySetAsSeries(BufferMedia, true);
   ArraySetAsSeries(BufferSinal, true);
   ArraySetAsSeries(BufferStoch, true);
//---👆👆👆👆👆👆👆👆👆👆👆👆   👆👆👆👆👆👆👆👆👆👆👆👆   

   
//--- Copia os dados das velas e organiza
   
   CopyRates(_Symbol, _Period, 0, 4, vela);
   ArraySetAsSeries(vela, true);
   
  
//--- Alimentar com dados a variavel de tick
   SymbolInfoTick(_Symbol,tick);
   
   
//--- RECEBE A DATA E HORA ATUAL
   
   hoje = TimeToString(TimeCurrent(), TIME_DATE);
   hora_atual = TimeCurrent();

//--- Chama a função de zerar se atingir a hora de zeragem
   
  if(hora_atual >= StringToTime(hoje+" "+hora_zeragem))
  {
     if(posicaoAberta)
     {
      zerar();
      return;
     }
  }   

//--- Chama a logica operacional

   logicaOperacional();
   
//--- Chama a função que preenche o alvo e stop
   
   preencheAlvoStop();
   
//--- Verifica se existem posições abertas chamando a função posições
   
   Posicoes();
    
//--- Faz o Envio das ordens
   if(hora_atual >= StringToTime(hoje+" "+hora_inicio) && hora_atual <= StringToTime(hoje+" "+hora_fim))
      enviaOrdens(); 

//--- Faz a zeragem condicional
   zeragemCondicional();   
      
      
      
   }//FIM DA FUNÇÃO ON TICK     
//-------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LOGICA OPERACIONAL                                               |
//+------------------------------------------------------------------+

   void logicaOperacional()
   {
//---👇👇👇👇👇👇👇👇👇👇👇👇👇   👇👇👇👇👇👇👇👇👇👇👇👇👇   
//--- LÓGICA OPERACIONAL
   distanciaPreco = MathAbs(vela[1].close-BufferMedia[1]);
   
   sinalC = (BufferStoch[1] > BufferSinal[1]) && (BufferStoch[2] < BufferSinal[2]) && (BufferSinal[2] < NivelInf) && (vela[1].close > BufferMedia[1]) && (distanciaPreco < distMaxPreco); 
   sinalV = (BufferStoch[1] < BufferSinal[1]) && (BufferStoch[2] > BufferSinal[2]) && (BufferSinal[2] > NivelSup) && (vela[1].close < BufferMedia[1]) && (distanciaPreco < distMaxPreco); 
   
//---👆👆👆👆👆👆👆👆👆👆👆👆   👆👆👆👆👆👆👆👆👆👆
   }
   
//+------------------------------------------------------------------+
//| PREENCHE ALVO E STOP                                             |
//+------------------------------------------------------------------+

   void preencheAlvoStop()
   {
//--- Atribuição de valores de take profit e stop loss
   
   double tpc1 = (m_symbol.NormalizePrice(tick.ask + takeProfit)); // Take profit da operação comprada
   double slc1 = (m_symbol.NormalizePrice(tick.ask - stopLoss)); // Preço Stop Loss comprada
   
   double tpv1 = (m_symbol.NormalizePrice(tick.ask - takeProfit)); // Take profit da operação comprada
   double slv1 = (m_symbol.NormalizePrice(tick.ask + stopLoss)); // Preço Stop Loss comprada
   
//--- Converte para points
   
      if (conversaoPoints == nao)
      {
         tpcN = tpc1;   
         slcN = slc1; 
      
         tpvN = tpv1;   
         slvN = slv1;  
      }
   
      else if(conversaoPoints == sim)
      {
         tpcN = tpc1;   
         slcN = slc1; 
         
         tpvN = tpv1*_Point;   
         slvN = slv1*_Point;   
      }
   }

//+------------------------------------------------------------------+
//| LOOP NAS POSIÇÕES ABERTAS                                        |
//+------------------------------------------------------------------+
   
void Posicoes()
  {
      posicaoAberta = false;
      
      for(int i = PositionsTotal() - 1;i >= 0; i--)
      {
        ulong posTicket = PositionGetTicket(i);
        
        if(PositionSelectByTicket(posTicket))    
        {
          string symbol = PositionGetString(POSITION_SYMBOL);
          ulong magic = PositionGetInteger(POSITION_MAGIC);
          
          if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == magic_number)) && symbol == _Symbol)
          {
            posicaoAberta = true;
            break;
          }
        }
      }
  } 
      
//+------------------------------------------------------------------+
//|   FAZ O ENVIO DE ORDENS                                          |
//+------------------------------------------------------------------+
   
   void enviaOrdens()
   {
   //--- Atribui o retorno da verificação da nova barra à variável newbar
   
    bool newbar = isNewBar();

   //--- Verifica de existem posições abertas, se sim faz a variável candle operado receber true
    
   if(posicaoAberta) candle_operado = true;
    
    else if(!posicaoAberta && newbar && (candle_operado=true)) candle_operado=false;
        
    if(candle_operado == false) 
    {
      if (sinalC && !posicaoAberta) m_trade.Buy (num_lots, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), slcN, tpcN, "Compra a Mercado");
      
      if (sinalV && !posicaoAberta) m_trade.Sell (num_lots, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), slvN, tpvN, "Venda a Mercado");
    }
   }
   

//+------------------------------------------------------------------+
//|   FAZ A ZERAGEM CONDICIONAL                                      |
//+------------------------------------------------------------------+

   void zeragemCondicional()
   {   
//---👇👇👇👇👇👇👇👇👇👇👇👇👇👇�👇👇👇    
//---LÓGICA OPCIONAL, CASO NÃO QUEIRA É SÓ ISOLAR AS 3 LINHAS ABAIXO
//--- ZERA AS POSIÇÕES EM UMA CONDIÇÃO ESPECIFICA

   long positionType = PositionGetInteger(POSITION_TYPE);
   if(posicaoAberta && (positionType == POSITION_TYPE_BUY) && (vela[1].close < BufferMedia[1])) zerar();
   if(posicaoAberta && (positionType == POSITION_TYPE_SELL) && (vela[1].close > BufferMedia[1])) zerar();
   
//---👆👆👆👆👆👆👆👆👆👆👆👆   👆👆👆👆👆👆    
   }

   
//+------------------------------------------------------------------+
//| REMOVE INDICADORES                                               |
//+------------------------------------------------------------------+

  void RemoveIndicadores()
  {
      long total_windows;
        
      if(ChartGetInteger(0,CHART_WINDOWS_TOTAL,0,total_windows))
         for(int i=0;i<total_windows;i++)
         {
            long total_indicators=ChartIndicatorsTotal(0,i);
            for(int j=0;j<total_indicators;j++)
               ChartIndicatorDelete(0,i,ChartIndicatorName(0,i,0));
         }
  }  
 
//+------------------------------------------------------------------+
//| VERIFICA A EXISTÊNCIA DE UMA NOVA BARRA                          |
//+------------------------------------------------------------------+

  bool isNewBar()
  {
      static datetime last_time=0;
      datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),ENUM_TIMEFRAMES(tempo_grafico),SERIES_LASTBAR_DATE);
   
      if(last_time==0)
      {
         last_time=lastbar_time;
         return(false);
      }
   
      if(last_time!=lastbar_time)
      {
         last_time=lastbar_time;
         return(true);
      }
   
      return(false);
  }

//+------------------------------------------------------------------+
//| FUNÇÃOS PARA AUXILIAR P/ DESENHA LINHAS HORIZONTAIS NO MACD      |
//+------------------------------------------------------------------+

void desenhaLinhaHorizontal(string nome, double linha, color cor)
  {
   ObjectDelete(0, nome);
   ObjectCreate(0, nome, OBJ_HLINE, 1, 0, linha);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
  }  
  
//+------------------------------------------------------------------+
//| ZERAR                                                            |
//+------------------------------------------------------------------+
  
  void zerar()
  {  
      for(int i = PositionsTotal() - 1;i >= 0; i--)
      {
        ulong posTicket = PositionGetTicket(i);
        
        if(PositionSelectByTicket(posTicket))    
        {
          string symbol = PositionGetString(POSITION_SYMBOL);
          ulong magic = PositionGetInteger(POSITION_MAGIC);
          
          if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == magic_number)) && symbol == _Symbol)
          {
            if(m_trade.PositionClose(posTicket, 25))
              Print("Posição zerada com sucesso. Código do Erro: ", m_trade.ResultRetcode(), ", Descrição do Erro: ", m_trade.ResultRetcodeDescription());
            else Print("Falha ao zerar a posição. Código do Erro: ", m_trade.ResultRetcode(), ", Descrição do Erro: ", m_trade.ResultRetcodeDescription()); 
          }
        }
      }
  }    