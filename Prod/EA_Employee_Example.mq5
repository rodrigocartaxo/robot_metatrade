//+------------------------------------------------------------------+
//|                                        EA_Employee_Example.mq5    |
//|                                  Copyright 2024, MetaQuotes Ltd.    |
//|                                             https://www.mql5.com    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| PARÂMETROS DE ENTRADA                                            |
//+------------------------------------------------------------------+
input group "=== CONFIGURAÇÃO DO EA ==="
input string    iEA_Name = "EA1";              // Nome do EA (deve corresponder ao CapitalManager)
input double   iLotSize = 0.01;                // Tamanho do lote
input int      iMagicNumber = 12345;           // Número mágico

input group "=== CONFIGURAÇÃO DE RISCO ==="
input double   iStopLoss = 50;                 // Stop Loss em pontos
input double   iTakeProfit = 100;              // Take Profit em pontos
input int      iMaxSpread = 30;                // Spread máximo permitido

//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS                                                |
//+------------------------------------------------------------------+
bool gCanTrade = true;                         // Pode operar?
int gLastCheckTime = 0;                        // Última verificação
double gCapitalStatus = 0;                     // Status do capital
double gDrawdownLevel = 0;                     // Nível de drawdown
CTrade trade;                                   // Trading (MQL5)
int gMA20Handle = INVALID_HANDLE;               // Handle MA 20
int gMA50Handle = INVALID_HANDLE;               // Handle MA 50

//+------------------------------------------------------------------+
//| FUNÇÃO DE INICIALIZAÇÃO                                          |
//+------------------------------------------------------------------+
int OnInit() {
   Print("=== EA EMPLOYEE STARTED ===");
   Print("EA Name: ", iEA_Name);
   Print("Magic Number: ", iMagicNumber);
   
   trade.SetExpertMagicNumber(iMagicNumber);
   
   // Criar handles das MAs (MQL5)
   gMA20Handle = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE);
   gMA50Handle = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_SMA, PRICE_CLOSE);
   if(gMA20Handle == INVALID_HANDLE || gMA50Handle == INVALID_HANDLE) {
      Print("ERRO ao criar handles de iMA. Código: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Verificar se o CapitalManager está ativo
   if(!CheckCapitalManagerStatus()) {
      Print("ERRO: CapitalManager não está ativo!");
      return INIT_FAILED;
   }
   
   Print("CapitalManager detectado e ativo!");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| FUNÇÃO DE FINALIZAÇÃO                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("=== EA EMPLOYEE STOPPED ===");
   Print("Reason: ", reason);
}

//+------------------------------------------------------------------+
//| FUNÇÃO PRINCIPAL - EXECUTADA A CADA TICK                         |
//+------------------------------------------------------------------+
void OnTick() {
   // Verificar status a cada segundo
   if(TimeCurrent() - gLastCheckTime >= 1) {
      CheckCapitalManagerStatus();
      gLastCheckTime = TimeCurrent();
   }
   
   // Se não pode operar, sair
   if(!gCanTrade) {
      return;
   }
   
   // Verificar condições de mercado
   if(!CheckMarketConditions()) {
      return;
   }
   
   // Executar estratégia
   ExecuteStrategy();
}

//+------------------------------------------------------------------+
//| VERIFICAR STATUS DO CAPITALMANAGER                               |
//+------------------------------------------------------------------+
bool CheckCapitalManagerStatus() {
   // Verificar se o sistema está ativo
   double systemActive = GlobalVariableGet("CAPITAL_SYSTEM_ACTIVE");
   if(systemActive != 1) {
      Print("CapitalManager não está ativo!");
      gCanTrade = false;
      return false;
   }
   
   // Verificar se este EA pode operar (usar MAGIC)
   string eaCanTradeVar = "CAPITAL_EA_" + IntegerToString(iMagicNumber) + "_CAN_TRADE";
   double canTrade = GlobalVariableGet(eaCanTradeVar);
   
   if(canTrade == 1) {
      if(!gCanTrade) {
         Print("EA LIBERADO para operar!");
      }
      gCanTrade = true;
   } else {
      if(gCanTrade) {
         Print("EA BLOQUEADO pelo CapitalManager!");
      }
      gCanTrade = false;
   }
   
   // Obter informações de drawdown
   gDrawdownLevel = GlobalVariableGet("CAPITAL_DRAWDOWN_LEVEL");
   gCapitalStatus = GlobalVariableGet("CAPITAL_CURRENT_DRAWDOWN");
   
   return true;
}

//+------------------------------------------------------------------+
//| VERIFICAR CONDIÇÕES DE MERCADO                                   |
//+------------------------------------------------------------------+
bool CanOpenPosition() {
   // Bloqueia se já existir posição deste EA (símbolo atual e mesmo magic)
   if(PositionSelect(_Symbol)) {
      long mg = (long)PositionGetInteger(POSITION_MAGIC);
      if(mg == iMagicNumber) {
         Print("Já existe posição aberta para este EA (magic=", iMagicNumber, ")");
         return false;
      }
   }
   return true;
}

bool CheckMarketConditions() {
   // Verificar spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > iMaxSpread) {
      Print("Spread muito alto: ", spread, " > ", iMaxSpread);
      return false;
   }
   
   // Permitir abrir somente se não houver posição aberta deste EA
   if(!CanOpenPosition()) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| EXECUTAR ESTRATÉGIA SIMPLES                                      |
//+------------------------------------------------------------------+
void ExecuteStrategy() {
   // Estratégia simples: compra quando MA20 > MA50 (MQL5 via CopyBuffer)
   double ma20 = 0.0, ma50 = 0.0;
   double buf20[1];
   double buf50[1];
   if(CopyBuffer(gMA20Handle, 0, 0, 1, buf20) != 1 || CopyBuffer(gMA50Handle, 0, 0, 1, buf50) != 1) {
      Print("Falha ao ler buffers das MAs. Código: ", GetLastError());
      return;
   }
   ma20 = buf20[0];
   ma50 = buf50[0];
   
   if(ma20 > ma50) {
      // Garantir novamente antes de enviar ordem
      if(!CanOpenPosition()) {
         return;
      }
      
      // Sinal de compra
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - (iStopLoss * _Point);
      double tp = ask + (iTakeProfit * _Point);
      
      trade.SetDeviationInPoints(30);
      bool ok = trade.Buy(iLotSize, _Symbol, 0.0, sl, tp, "EA_Employee_" + iEA_Name);
      if(ok) {
         Print("Ordem de COMPRA enviada. Ticket: ", trade.ResultOrder());
         Print("Preço: ", ask, " SL: ", sl, " TP: ", tp);
      } else {
         Print("ERRO ao enviar ordem: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| CONTAR POSIÇÕES ABERTAS                                          |
//+------------------------------------------------------------------+
int CountOpenPositions() {
   int count = 0;
   if(PositionSelect(_Symbol)) {
      long mg = (long)PositionGetInteger(POSITION_MAGIC);
      if(mg == iMagicNumber) {
         count = 1; // considerando 1 posição relevante neste símbolo/magic
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| FUNÇÃO PARA RELATAR STATUS AO CAPITALMANAGER                     |
//+------------------------------------------------------------------+
void ReportStatusToCapitalManager() {
   // Calcular lucro/prejuízo atual
   double totalProfit = 0;
   int totalTrades = 0;
   int winTrades = 0;
   int lossTrades = 0;
   
   // Lucro de posições abertas
   double openProfit = 0;
   if(PositionSelect(_Symbol)) {
      long mg = (long)PositionGetInteger(POSITION_MAGIC);
      if(mg == iMagicNumber) {
         openProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   // Histórico do dia (exemplo)
   datetime start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime end = TimeCurrent();
   if(HistorySelect(start, end)) {
      int dealsTotal = (int)HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++) {
         ulong dealTicket = HistoryDealGetTicket(i);
         string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         long mg = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         long entry = (long)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(sym == _Symbol && mg == iMagicNumber && entry == DEAL_ENTRY_OUT) {
            double p = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            totalTrades++;
            if(p > 0) winTrades++; else if(p < 0) lossTrades++;
            totalProfit += p;
         }
      }
   }
   
   double totalProfitWithOpen = totalProfit + openProfit;
   
   // Reportar via variáveis globais (baseado em MAGIC)
   string magicStr = IntegerToString(iMagicNumber);
   string eaProfitVar = "CAPITAL_EA_" + magicStr + "_PROFIT";
   string eaTradesVar = "CAPITAL_EA_" + magicStr + "_TRADES";
   string eaWinsVar = "CAPITAL_EA_" + magicStr + "_WINS";
   string eaLossesVar = "CAPITAL_EA_" + magicStr + "_LOSSES";
   string eaCurrentVar = "CAPITAL_EA_" + magicStr + "_CURRENT";
   
   GlobalVariableSet(eaProfitVar, totalProfitWithOpen);
   GlobalVariableSet(eaTradesVar, totalTrades);
   GlobalVariableSet(eaWinsVar, winTrades);
   GlobalVariableSet(eaLossesVar, lossTrades);
   GlobalVariableSet(eaCurrentVar, iLotSize * 100000);
   
   // Log detalhado
   Print("=== STATUS REPORTADO AO CAPITALMANAGER ===");
   Print("EA (MAGIC): ", magicStr);
   Print("Profit Total: ", totalProfitWithOpen);
   Print("Trades: ", totalTrades, " (Wins: ", winTrades, ", Losses: ", lossTrades, ")");
   Print("Open Positions Profit: ", openProfit);
   Print("Capital em uso: ", iLotSize * 100000);
}

//+------------------------------------------------------------------+
//| FUNÇÃO CHAMADA A CADA ORDEM EXECUTADA                            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result) {
   
   if(trans.order_type == ORDER_TYPE_BUY || trans.order_type == ORDER_TYPE_SELL) {
      Print("Transação executada: ", trans.order_type, " Volume: ", trans.volume);
      
      // Reportar status ao CapitalManager
      ReportStatusToCapitalManager();
   }
}
