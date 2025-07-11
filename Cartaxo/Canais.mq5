//+------------------------------------------------------------------+
//|                                              Canais_Percentuais.mq5 |
//|                                                         Versão 2.0 |
//|                                       Canal de Percentuais Superior |
//+------------------------------------------------------------------+
#property copyright "Atualizado 2025"
#property link      ""
#property version   "2.00"
#property description "EA para criar canais superiores baseados em percentuais a partir de uma linha base"
#property indicator_chart_window

// Parâmetros de entrada organizados em grupos  
input group "=== CONFIGURAÇÕES PRINCIPAIS ==="
input double linha_base = 1.0000000;              // Valor da linha base (última linha inferior)
input double percentual = 1.0;                 // Percentual para as linhas superiores (%)
input int quantidade_canais = 5;               // Quantidade de canais superiores
input bool auto_ajustar_tempo = true;          // Auto-ajustar tempo das linhas

input group "=== CONFIGURAÇÕES DE TEMPO ==="
input datetime tempo_inicio_usuario = __DATE__;       // Tempo de início (0 = tempo atual)
input int extensao_periodos = 500;             // Extensão das linhas em períodos

input group "=== CONFIGURAÇÕES VISUAIS ==="
input color cor_linha_base = clrRed;           // Cor da linha base (inferior)
input color cor_linhas_superiores = clrLimeGreen; // Cor das linhas superiores
input int espessura_linha = 2;                 // Espessura das linhas (1-5)
input ENUM_LINE_STYLE estilo_linha_base = STYLE_SOLID;     // Estilo da linha base
input ENUM_LINE_STYLE estilo_superiores = STYLE_DASH;      // Estilo das linhas superiores

input group "=== CONFIGURAÇÕES AVANÇADAS ==="
input bool mostrar_labels = true;              // Mostrar rótulos com valores
input bool notificar_cruzamento = false;       // Notificar quando preço cruzar canais
input int cor_transparencia = 0;               // Transparência das linhas (0-255)

// Variáveis globais
string prefixo_objetos = "CanalPerc_";
string nome_linha_base;
datetime ultimo_tempo_atualizacao = 0;
double ultimo_preco_bid = 0;
bool inicializado_com_sucesso = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validar parâmetros de entrada
   if(!ValidarParametros())
   {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Configurar nomes dos objetos
   ConfigurarNomes();
   
   // Limpar objetos anteriores
   LimparTodosObjetos();
   
   // Criar os canais
   if(!CriarCanais())
   {
      Print("ERRO: Falha ao criar canais");
      return(INIT_FAILED);
   }
   
   // Registrar sucesso da inicialização
   inicializado_com_sucesso = true;
   ultimo_tempo_atualizacao = TimeCurrent();
   ultimo_preco_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Exibir informações de inicialização
   ExibirInformacoesInicializacao();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Limpar todos os objetos criados
   LimparTodosObjetos();
   
   // Informar sobre a remoção
   string motivo = ObterMotivoDesinicializacao(reason);
   Print("EA Canais Percentuais removido - Motivo: ", motivo);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!inicializado_com_sucesso) return;
   
   // Atualizar canais se necessário
   if(auto_ajustar_tempo && DeveAtualizarCanais())
   {
      AtualizarCanais();
   }
   
   // Verificar cruzamentos se habilitado
   if(notificar_cruzamento)
   {
      VerificarCruzamentos();
   }
}

//+------------------------------------------------------------------+
//| Função para validar parâmetros                                  |
//+------------------------------------------------------------------+
bool ValidarParametros()
{
   bool parametros_validos = true;
   
   if(quantidade_canais <= 0)
   {
      Print("ERRO: Quantidade de canais deve ser maior que 0");
      parametros_validos = false;
   }
   
   if(quantidade_canais > 15)
   {
      Print("AVISO: Limitando quantidade de canais superiores a 15 para melhor performance");
   }
   
   if(percentual <= 0)
   {
      Print("ERRO: Percentual deve ser maior que 0");
      parametros_validos = false;
   }
   
   if(linha_base <= 0)
   {
      Print("AVISO: Linha base com valor negativo ou zero pode gerar resultados inesperados");
   }
   
   if(espessura_linha < 1 || espessura_linha > 5)
   {
      Print("AVISO: Espessura da linha deve estar entre 1 e 5");
   }
   
   if(extensao_periodos < 10)
   {
      Print("AVISO: Extensão mínima recomendada: 10 períodos");
   }
   
   return parametros_validos;
}

//+------------------------------------------------------------------+
//| Função para configurar nomes dos objetos                       |
//+------------------------------------------------------------------+
void ConfigurarNomes()
{
   nome_linha_base = prefixo_objetos + "Base";
}

//+------------------------------------------------------------------+
//| Função para criar os canais                                     |
//+------------------------------------------------------------------+
bool CriarCanais()
{
   // Determinar tempo de início e fim
   datetime tempo_inicio = (tempo_inicio_usuario == 0) ? TimeCurrent() : tempo_inicio_usuario;
   datetime tempo_fim = tempo_inicio + PeriodSeconds() * extensao_periodos;
   
   // Criar linha base (inferior)
   if(!CriarLinhaBase(tempo_inicio, tempo_fim))
   {
      return false;
   }
   
   // Criar canais superiores
   int canais_criados = 0;
   for(int i = 1; i <= MathMin(quantidade_canais, 15); i++)
   {
      if(CriarCanalSuperior(i, tempo_inicio, tempo_fim))
      {
         canais_criados++;
      }
   }
   
   // Atualizar visualização
   ChartRedraw(0);
   
   Print("Canais criados com sucesso: ", canais_criados, " níveis superiores + linha base");
   return true;
}

//+------------------------------------------------------------------+
//| Função para criar linha base                                    |
//+------------------------------------------------------------------+
bool CriarLinhaBase(datetime inicio, datetime fim)
{
   if(!ObjectCreate(0, nome_linha_base, OBJ_TREND, 0, inicio, linha_base, fim, linha_base))
   {
      Print("Erro ao criar linha base: ", GetLastError());
      return false;
   }
   
   // Configurar propriedades
   ObjectSetInteger(0, nome_linha_base, OBJPROP_COLOR, cor_linha_base);
   ObjectSetInteger(0, nome_linha_base, OBJPROP_WIDTH, espessura_linha);
   ObjectSetInteger(0, nome_linha_base, OBJPROP_STYLE, estilo_linha_base);
   ObjectSetInteger(0, nome_linha_base, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, nome_linha_base, OBJPROP_BACK, false);
   
   // Adicionar rótulo se habilitado
   if(mostrar_labels)
   {
      string nome_label = nome_linha_base + "_Label";
      if(ObjectCreate(0, nome_label, OBJ_TEXT, 0, inicio, linha_base))
      {
         ObjectSetString(0, nome_label, OBJPROP_TEXT, "Base: " + DoubleToString(linha_base, _Digits));
         ObjectSetInteger(0, nome_label, OBJPROP_COLOR, cor_linha_base);
         ObjectSetInteger(0, nome_label, OBJPROP_FONTSIZE, 8);
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Função para criar canal superior específico                     |
//+------------------------------------------------------------------+
bool CriarCanalSuperior(int nivel, datetime inicio, datetime fim)
{
   // Calcular valor para este nível superior
   double multiplicador = nivel * percentual / 100.0;
   double valor_superior = linha_base + (linha_base * multiplicador);
   
   // Nome único para esta linha
   string nome_superior = prefixo_objetos + "Superior_" + IntegerToString(nivel);
   
   // Criar linha superior
   if(!ObjectCreate(0, nome_superior, OBJ_TREND, 0, inicio, valor_superior, fim, valor_superior))
   {
      Print("Erro ao criar linha superior ", nivel, ": ", GetLastError());
      return false;
   }
   
   // Configurar propriedades
   ObjectSetInteger(0, nome_superior, OBJPROP_COLOR, cor_linhas_superiores);
   ObjectSetInteger(0, nome_superior, OBJPROP_WIDTH, espessura_linha);
   ObjectSetInteger(0, nome_superior, OBJPROP_STYLE, estilo_superiores);
   ObjectSetInteger(0, nome_superior, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, nome_superior, OBJPROP_BACK, false);
   
   // Adicionar rótulo se habilitado
   if(mostrar_labels)
   {
      string nome_label = nome_superior + "_Label";
      if(ObjectCreate(0, nome_label, OBJ_TEXT, 0, inicio, valor_superior))
      {
         string texto = "+" + DoubleToString(nivel * percentual, 1) + "% (" + 
                       DoubleToString(valor_superior, _Digits) + ")";
         ObjectSetString(0, nome_label, OBJPROP_TEXT, texto);
         ObjectSetInteger(0, nome_label, OBJPROP_COLOR, cor_linhas_superiores);
         ObjectSetInteger(0, nome_label, OBJPROP_FONTSIZE, 8);
      }
   }
   
   Print("Canal Superior ", nivel, " - Valor: ", DoubleToString(valor_superior, _Digits), 
         " (+", DoubleToString(nivel * percentual, 1), "%)");
   
   return true;
}

//+------------------------------------------------------------------+
//| Função para atualizar os canais                                 |
//+------------------------------------------------------------------+
void AtualizarCanais()
{
   datetime tempo_atual = TimeCurrent();
   datetime tempo_fim = tempo_atual + PeriodSeconds() * extensao_periodos;
   
   // Atualizar linha base
   if(ObjectFind(0, nome_linha_base) >= 0)
   {
      ObjectSetInteger(0, nome_linha_base, OBJPROP_TIME, 1, tempo_fim);
   }
   
   // Atualizar todos os canais superiores
   for(int i = 1; i <= quantidade_canais; i++)
   {
      string nome_superior = prefixo_objetos + "Superior_" + IntegerToString(i);
      
      if(ObjectFind(0, nome_superior) >= 0)
      {
         // Recalcular valor
         double multiplicador = i * percentual / 100.0;
         double valor_superior = linha_base + (linha_base * multiplicador);
         
         // Atualizar linha
         ObjectSetInteger(0, nome_superior, OBJPROP_TIME, 1, tempo_fim);
         ObjectSetDouble(0, nome_superior, OBJPROP_PRICE, 0, valor_superior);
         ObjectSetDouble(0, nome_superior, OBJPROP_PRICE, 1, valor_superior);
      }
   }
   
   ultimo_tempo_atualizacao = tempo_atual;
}

//+------------------------------------------------------------------+
//| Função para verificar se deve atualizar canais                  |
//+------------------------------------------------------------------+
bool DeveAtualizarCanais()
{
   // Atualizar a cada 10 minutos ou mudança significativa de preço
   datetime tempo_atual = TimeCurrent();
   double preco_atual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   bool tempo_expirado = (tempo_atual - ultimo_tempo_atualizacao) > 600; // 10 minutos
   bool preco_mudou = MathAbs(preco_atual - ultimo_preco_bid) > _Point * 100;
   
   if(tempo_expirado || preco_mudou)
   {
      ultimo_preco_bid = preco_atual;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Função para verificar cruzamentos                               |
//+------------------------------------------------------------------+
void VerificarCruzamentos()
{
   static double ultimo_preco_check = 0;
   double preco_atual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(ultimo_preco_check == 0)
   {
      ultimo_preco_check = preco_atual;
      return;
   }
   
   // Verificar cruzamento da linha base
   if((ultimo_preco_check <= linha_base && preco_atual > linha_base) ||
      (ultimo_preco_check >= linha_base && preco_atual < linha_base))
   {
      Alert("Preço cruzou a linha base: ", DoubleToString(linha_base, _Digits));
   }
   
   // Verificar cruzamento dos canais superiores
   for(int i = 1; i <= quantidade_canais; i++)
   {
      double multiplicador = i * percentual / 100.0;
      double valor_superior = linha_base + (linha_base * multiplicador);
      
      if((ultimo_preco_check <= valor_superior && preco_atual > valor_superior) ||
         (ultimo_preco_check >= valor_superior && preco_atual < valor_superior))
      {
         Alert("Preço cruzou canal superior ", i, ": ", DoubleToString(valor_superior, _Digits));
      }
   }
   
   ultimo_preco_check = preco_atual;
}

//+------------------------------------------------------------------+
//| Função para limpar todos os objetos                             |
//+------------------------------------------------------------------+
void LimparTodosObjetos()
{
   // Limpar linha base
   ObjectDelete(0, nome_linha_base);
   ObjectDelete(0, nome_linha_base + "_Label");
   
   // Limpar canais superiores
   for(int i = 1; i <= 15; i++) // Máximo possível
   {
      string nome_superior = prefixo_objetos + "Superior_" + IntegerToString(i);
      ObjectDelete(0, nome_superior);
      ObjectDelete(0, nome_superior + "_Label");
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Função para exibir informações de inicialização                 |
//+------------------------------------------------------------------+
void ExibirInformacoesInicializacao()
{
   Print("=== EA CANAIS PERCENTUAIS INICIADO ===");
   Print("Linha Base: ", DoubleToString(linha_base, _Digits));
   Print("Percentual: ", DoubleToString(percentual, 1), "%");
   Print("Quantidade de canais superiores: ", quantidade_canais);
   Print("Tempo de início: ", (tempo_inicio_usuario == 0) ? "Tempo atual" : TimeToString(tempo_inicio_usuario));
   Print("Auto-ajustar tempo: ", (auto_ajustar_tempo ? "SIM" : "NÃO"));
   Print("Mostrar rótulos: ", (mostrar_labels ? "SIM" : "NÃO"));
   Print("Notificar cruzamentos: ", (notificar_cruzamento ? "SIM" : "NÃO"));
   Print("==========================================");
}

//+------------------------------------------------------------------+
//| Função para obter motivo da desinicialização                   |
//+------------------------------------------------------------------+
string ObterMotivoDesinicializacao(int reason)
{
   switch(reason)
   {
      case REASON_REMOVE: return "EA removido do gráfico";
      case REASON_RECOMPILE: return "EA recompilado";
      case REASON_CHARTCHANGE: return "Mudança de símbolo/período";
      case REASON_CHARTCLOSE: return "Gráfico fechado";
      case REASON_PARAMETERS: return "Parâmetros alterados";
      case REASON_ACCOUNT: return "Conta alterada";
      case REASON_TEMPLATE: return "Template aplicado";
      case REASON_INITFAILED: return "Falha na inicialização";
      case REASON_CLOSE: return "Terminal fechado";
      default: return "Motivo desconhecido";
   }
}

//+------------------------------------------------------------------+
//| Função para recalcular canais (externa)                         |
//