//+------------------------------------------------------------------+
//| BOS SMC EA.mq5 |
//| Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader. |
//| https://youtube.com/@ForexAlgo-Trader? |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>
#include <.\Personal\\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>



//Trade obj_Trade;
input group " EA GENERAL SETTINGS " 
input double inpLot = 0.01;  // Lotsize
input int sl_pts = 300;       // Stop Loss Points
input int tp_pts = 300;       // Take Profit Points
input double r2r_ratio = 7;   // Risk : Reward Ratio
sinput int object_code = 77;  // Object Code
sinput string src_code1 =
    "https://t.me/forexalgo_trading";  // Source Code HERE 👉
sinput string src_code2 =
    "https://youtube.com/@ForexAlgo-Trader?";  // Join Community HERE 👉
input int totalTrades = 1;                     // Total Possible Open Trades
sinput color def_clr_up = clrBlue;             // Swing High Color
sinput color def_clr_down = clrRed;            // Swing Low Color
input int ext_bars = 5;                        // BoS Scan Length in Bars
sinput bool prt = true;                        // Print Statements
sinput int width = 2;                          // Width
sinput int fontSize = 10;                      // Font Size

MyPainel painel;
MyMagicNumber myMagicNumber;
TraderInfos tradeInfos;
MyCtrader trade;

//+------------------------------------------------------------------+
//| Expert initialization function |
//+------------------------------------------------------------------+
int OnInit() { 
   
   
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),StringSubstr(_Symbol,0,3));
   tradeInfos.symbol = _Symbol;
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
   
   EventSetTimer(1);  


   return (INIT_SUCCEEDED); 
}
//+------------------------------------------------------------------+
//| Expert deinitialization function |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   painel.Destroy(reason); 
   EventKillTimer();

}
void OnTimer(){

    painel.OnTimer();
}
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );

}
//+------------------------------------------------------------------+
//| Expert tick function |
//+------------------------------------------------------------------+
void OnTick() {
  static bool isNewBar = false;
  int currBars = iBars(_Symbol, _Period);
  static int prevBars = currBars;
  if (prevBars == currBars) {
    isNewBar = false;
  } else if (prevBars != currBars) {
    isNewBar = true;
    prevBars = currBars;
  }
  painel.OnTick(); 

  double price_step = SymbolInfoDouble(_Symbol , SYMBOL_TRADE_TICK_SIZE );
  const int length = ext_bars;
  const int limit = ext_bars;
  int right_index, left_index;
  bool isSwingHigh = true, isSwingLow = true;

  static double swing_H = -1.0, swing_L = -1.0;
  int curr_bar = limit;
  if (isNewBar) {
    for (int j = 1; j <= length; j++) {
      right_index = curr_bar - j;
      left_index = curr_bar + j;
      if ((high(curr_bar) <= high(right_index)) ||
          (high(curr_bar) < high(left_index))) {
        isSwingHigh = false;
      }
      if ((low(curr_bar) >= low(right_index)) ||
          (low(curr_bar) > low(left_index))) {
        isSwingLow = false;
      }
    }
    if (isSwingHigh) {
      swing_H = high(curr_bar);
      if (prt) {
        Print("UP @ BAR INDEX ", curr_bar, " of High: ", high(curr_bar));
      }
      drawSwingPoint(TimeToString(time(curr_bar)), time(curr_bar),
                     high(curr_bar), object_code, def_clr_up, -1);
    }
    if (isSwingLow) {
      swing_L = low(curr_bar);
      if (prt) {
        Print("DOWN @ BAR INDEX ", curr_bar, " of Low: ", low(curr_bar));
      }
      drawSwingPoint(TimeToString(time(curr_bar)), time(curr_bar),
                     low(curr_bar), object_code, def_clr_down, 1);
    }
  }

  double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
  double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  
  

  if (swing_H > 0 && Bid > swing_H && close(1) > swing_H) {
    if (prt) {
      Print("BREAK UP NOW");
    }
    int swing_H_index = 0;
    for (int i = 0; i <= length * 2 + 1000; i++) {
      double high_sel = high(i);
      if (high_sel == swing_H) {
        swing_H_index = i;
        if (prt) {
          Print("BREAK HIGH @ BAR ", swing_H_index);
        }
        break;
      }
    }
    drawBreakLevel(TimeToString(time(0)), time(swing_H_index),
                   high(swing_H_index), time(0 + 1), high(swing_H_index),
                   def_clr_up, -1);
    swing_H = -1.0;

    //--- Open Buy
     Print("Prepare to by ");
 
    
    double price_step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE );
    
    double SL_Buy =  roundPriceH9K(Bid - sl_pts * r2r_ratio * _Point, price_step);
    double TP_Buy = roundPriceH9K(Bid + tp_pts * _Point, price_step);
    
     /*double SL_Buy           = roundPriceH9K(Bid - (Bid *iStopLossPercent /100),price_step);
     double TP_Buy           = roundPriceH9K(Bid + (Bid *iTakeProfitPercent /100) ,price_step);*/
     
    
    
    if (//Check2_Margin(ORDER_TYPE_BUY, trade_lots) &&
       // Check3_VolumeLimit(trade_lots) &&
        Check4_TradeLevels(POSITION_TYPE_BUY, SL_Buy, TP_Buy)) {
        trade.closeAllPositions(tradeInfos);
        
        //tradeInfos.lot_size = trade_lots;
        tradeInfos.amount   = roundPriceH9K(Ask,price_step);
        tradeInfos.order_type = ORDER_TYPE_BUY;
        tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
        tradeInfos.stop_loss =SL_Buy; 
        tradeInfos.take_profit =TP_Buy; 
        tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ _Symbol;
        trade.sendOrder(tradeInfos); 
      
     // obj_Trade.Buy(trade_lots, _Symbol, roundPriceH9K(Ask,price_step), roundPriceH9K(SL_Buy,price_step), roundPriceH9K(TP_Buy,price_step),"BoS Break Up BUY");
                            /*if (PositionsTotal() < totalTrades) {
        
      }*/
    }
    return;
  } else if (swing_L > 0 && Ask < swing_L && close(1) < swing_L) {
    if (prt) {
      Print("BREAK DOWN NOW");
    }
    int swing_L_index = 0;
    for (int i = 0; i <= length * 2 + 1000; i++) {
      double low_sel = low(i);
      if (low_sel == swing_L) {
        swing_L_index = i;
        if (prt) {
          Print("BREAK LOW @ BAR ", swing_L_index);
        }
        break;
      }
    }
    drawBreakLevel(TimeToString(time(0)), time(swing_L_index),
                   low(swing_L_index), time(0 + 1), low(swing_L_index),
                   def_clr_down, 1);
    swing_L = -1.0;

    //--- Open Sell
    Print("Prepare to sell ");
   
    
    
    double SL_Sell =  roundPriceH9K(Ask + sl_pts * r2r_ratio * _Point,price_step);
    double TP_Sell =  roundPriceH9K(Ask - tp_pts * _Point,price_step);
    
     /*double SL_Sell           = roundPriceH9K(Ask + (Ask *iStopLossPercent /100),price_step);
     double TP_Sell           = roundPriceH9K(Ask - (Ask *iTakeProfitPercent /100) ,price_step);*/
    
    
    
    
    if (//Check2_Margin(ORDER_TYPE_SELL, trade_lots) &&
        //Check3_VolumeLimit(trade_lots) &&
        Check4_TradeLevels(POSITION_TYPE_SELL, SL_Sell, TP_Sell)) {
        
        trade.closeAllPositions(tradeInfos);
        //tradeInfos.lot_size = trade_lots;
        tradeInfos.amount   = roundPriceH9K(Ask,price_step);
        tradeInfos.order_type = ORDER_TYPE_SELL;
        tradeInfos.order_type_time = i24h?ORDER_TIME_GTC:ORDER_TIME_DAY;
        tradeInfos.stop_loss =SL_Sell; 
        tradeInfos.take_profit =TP_Sell; 
        tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME)+ _Symbol;
        trade.sendOrder(tradeInfos); 
     
     /*obj_Trade.Sell(trade_lots, _Symbol, roundPriceH9K(Bid,price_step), roundPriceH9K(SL_Sell,price_step), roundPriceH9K(TP_Sell,price_step),
                       "BoS Break Down SELL");-*
      /*if (PositionsTotal() < totalTrades) {
        
      }*/
    }
    return;
  }
}
//+------------------------------------------------------------------+
double high(int index) { return (iHigh(_Symbol, _Period, index)); }
double low(int index) { return (iLow(_Symbol, _Period, index)); }
double close(int index) { return (iClose(_Symbol, _Period, index)); }
datetime time(int index) { return (iTime(_Symbol, _Period, index)); }
void drawSwingPoint(string objName, datetime time, double price, int arrCode,
                    color clr, int direction) {
  if (ObjectFind(0, objName) < 0) {
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrCode);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
    if (direction > 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
    if (direction < 0)
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    string txt = " BoS";
    string objNameDescr = objName + txt;
    ObjectCreate(0, objNameDescr, OBJ_TEXT, 0, time, price);
    ObjectSetInteger(0, objNameDescr, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objNameDescr, OBJPROP_FONTSIZE, fontSize);
    if (direction > 0) {
      ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
    }
    if (direction < 0) {
      ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
    }
  }
  ChartRedraw(0);
}
void drawBreakLevel(string objName, datetime time1, double price1,
                    datetime time2, double price2, color clr, int direction) {
  if (ObjectFind(0, objName) < 0) {
    ObjectCreate(0, objName, OBJ_ARROWED_LINE, 0, time1, price1, time2, price2);
    ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
    ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
    string txt = " Break ";
    string objNameDescr = objName + txt;
    ObjectCreate(0, objNameDescr, OBJ_TEXT, 0, time2, price2);
    ObjectSetInteger(0, objNameDescr, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objNameDescr, OBJPROP_FONTSIZE, fontSize);
    if (direction > 0) {
      ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
    }
    if (direction < 0) {
      ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
    }
  }
  ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 1. CHECK TRADING VOLUME |
//+------------------------------------------------------------------+
double Check1_ValidateVolume_Lots(double lots) {
  double symbolVol_Min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double symbolVol_Max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double symbolVol_STEP = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  double accepted_Lots;
  double CurrentLots = lots;
  accepted_Lots = MathMax(MathMin(CurrentLots, symbolVol_Max), symbolVol_Min);
  int lotDigits = 0;
  if (symbolVol_Min == 1) lotDigits = 0;
  if (symbolVol_Min == 0.1) lotDigits = 1;
  if (symbolVol_Min == 0.01) lotDigits = 2;
  if (symbolVol_Min == 0.001) lotDigits = 3;
  double normalized_lots = NormalizeDouble(accepted_Lots, lotDigits);
  return (normalized_lots);
}

//+------------------------------------------------------------------+
//| 2. CHECK MONEY/MARGIN TO OPEN POSITION |
//+------------------------------------------------------------------+
bool Check2_Margin(ENUM_ORDER_TYPE Order_Type, double lot_Vol) {
  /*double margin;
  double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
  double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  double openPrice = (Order_Type == ORDER_TYPE_BUY) ? Ask : Bid;
  bool result =
      OrderCalcMargin(Order_Type, _Symbol, lot_Vol, openPrice, margin);
  if (result == false) {
    ResetLastError();
    Print("ERROR: Something Unexpected Happened While Calculating Margin\n",
          "RESULT = ", result, ", ERROR = ", _LastError);
    return (false);
  }
  if (margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE)) {
    Print("WARNING! NOT ENOUGH MARGIN TO OPEN THE POSITION. NEEDED = ", margin);
    return (false);
  }*/
  return (true);
}
bool Check3_VolumeLimit(double lots_Vol_Limit) {
 /* double volumeLimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
  double symb_Vol_Max40 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double allowed_Vol_Lim = (volumeLimit == 0) ? symb_Vol_Max40 : volumeLimit;
  if (getAllVolume() + lots_Vol_Limit > allowed_Vol_Lim) {
    Print("WARNING! VOLUME LIMIT REACHED: LIMIT = ", allowed_Vol_Lim);
    return (false);
  }*/
  return (true);
}

double getAllVolume() {
  ulong ticket = 0;
  double Volume = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--) {
    ticket = PositionGetTicket(i);
    if (PositionSelectByTicket(ticket)) {
      if (PositionGetString(POSITION_SYMBOL) == _Symbol) {
        Volume += PositionGetDouble(POSITION_VOLUME);
      }
    }
  }
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    ticket = OrderGetTicket(i);
    if (OrderSelect(ticket)) {
      if (OrderGetString(ORDER_SYMBOL) == _Symbol) {
        Volume += OrderGetDouble(ORDER_VOLUME_CURRENT);
      }
    }
  }
  return (Volume);
}
//+------------------------------------------------------------------+
//| 4. CHECK TRADE LEVELS |
//+------------------------------------------------------------------+
bool Check4_TradeLevels(ENUM_POSITION_TYPE pos_Type, double sl = 0,
                        double tp = 0, ulong tkt = 0) {
 /* double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
  double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
  int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  double stopLevel_Pts = stopLevel * _Point;
  double freezeLevel_Pts = freezeLevel * _Point;
  if (pos_Type == POSITION_TYPE_BUY) {
    // STOP LEVELS CHECK
    if (tp > 0 && tp - Bid < stopLevel_Pts) {
      Print("WARNING! BUY TP ", tp, ", Bid ", Bid,
            " (TP-Bid = ", NormalizeDouble((tp - Bid) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      return (false);
    }
    if (sl > 0 && Bid - sl < stopLevel_Pts) {
      Print("WARNING! BUY SL ", sl, ", Bid ", Bid,
            " (Bid-SL = ", NormalizeDouble((Bid - sl) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      return (false);
    }
    // FREEZE LEVELS CHECK
    if (tp > 0 && tp - Bid < freezeLevel_Pts) {
      Print("WARNING! BUY TP ", tp, ", Bid ", Bid,
            " (TP-Bid = ", NormalizeDouble((tp - Bid) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      return (false);
    }
    if (sl > 0 && Bid - sl < freezeLevel_Pts) {
      Print("WARNING! BUY SL ", sl, ", Bid ", Bid,
            " (Bid-SL = ", NormalizeDouble((Bid - sl) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      return (false);
    }
  }
  if (pos_Type == POSITION_TYPE_SELL) {
    // STOP LEVELS CHECK
    if (tp > 0 && Ask - tp < stopLevel_Pts) {
      Print("WARNING! SELL TP ", tp, ", Ask ", Ask,
            " (Ask-TP = ", NormalizeDouble((Ask - tp) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      return (false);
    }
    if (sl > 0 && sl - Ask < stopLevel_Pts) {
      Print("WARNING! SELL SL ", sl, ", Ask ", Ask,
            " (SL-Ask = ", NormalizeDouble((sl - Ask) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      return (false);
    }
    // FREEZE LEVELS CHECK
    if (tp > 0 && Ask - tp < freezeLevel_Pts) {
      Print("WARNING! SELL TP ", tp, ", Ask ", Ask,
            " (Ask-TP = ", NormalizeDouble((Ask - tp) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      return (false);
    }
    if (sl > 0 && sl - Ask < freezeLevel_Pts) {
      Print("WARNING! SELL SL ", sl, ", Ask ", Ask,
            " (SL-Ask = ", NormalizeDouble((sl - Ask) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      return (false);
    }
  }
  if (tkt > 0) {
    bool result = PositionSelectByTicket(tkt);
    if (result == false) {
      Print("ERROR Selecting The Position (CHECK) With Ticket # ", tkt);
      return (false);
    }
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double pos_SL = PositionGetDouble(POSITION_SL);
    double pos_TP = PositionGetDouble(POSITION_TP);
    bool slChanged = MathAbs(pos_SL - sl) > point;
    bool tpChanged = MathAbs(pos_TP - tp) > point;
    // bool slChanged = pos_SL != sl;
    // bool tpChanged = pos_TP != tp;
    if (!slChanged && !tpChanged) {
      Print("ERROR. Pos # ", tkt, " Already has Levels of SL: ", pos_SL,
            ", TP: ", pos_TP, " NEW[SL = ", sl, " | TP = ", tp,
            "]. NO POINT IN MODIFYING!!!");
      return (false);
    }
  }*/
  return (true);
}
//+------------------------------------------------------------------+
//| 5. CHECK & CORRECT TRADE LEVELS |
//+------------------------------------------------------------------+
double Check5_TradeLevels_Rectify(ENUM_POSITION_TYPE pos_Type, double sl = 0,
                                  double tp = 0) {
  double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
  double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
  int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  double stopLevel_Pts = stopLevel * _Point;
  double freezeLevel_Pts = freezeLevel * _Point;
  double accepted_price = 0.0;
  if (pos_Type == POSITION_TYPE_BUY) {
    // STOP LEVELS CHECK
    if (tp > 0 && tp - Bid < stopLevel_Pts) {
      accepted_price = Bid + stopLevel_Pts;
      Print("WARNING! BUY TP ", tp, ", Bid ", Bid,
            " (TP-Bid = ", NormalizeDouble((tp - Bid) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
    if (sl > 0 && Bid - sl < stopLevel_Pts) {
      accepted_price = Bid - stopLevel_Pts;
      Print("WARNING! BUY SL ", sl, ", Bid ", Bid,
            " (Bid-SL = ", NormalizeDouble((Bid - sl) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
    // FREEZE LEVELS CHECK
    if (tp > 0 && tp - Bid < freezeLevel_Pts) {
      accepted_price = Bid + freezeLevel_Pts;
      Print("WARNING! BUY TP ", tp, ", Bid ", Bid,
            " (TP-Bid = ", NormalizeDouble((tp - Bid) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
    if (sl > 0 && Bid - sl < freezeLevel_Pts) {
      accepted_price = Bid - freezeLevel_Pts;
      Print("WARNING! BUY SL ", sl, ", Bid ", Bid,
            " (Bid-SL = ", NormalizeDouble((Bid - sl) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
  }
  if (pos_Type == POSITION_TYPE_SELL) {
    // STOP LEVELS CHECK
    if (tp > 0 && Ask - tp < stopLevel_Pts) {
      accepted_price = Ask - stopLevel_Pts;
      Print("WARNING! SELL TP ", tp, ", Ask ", Ask,
            " (Ask-TP = ", NormalizeDouble((Ask - tp) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
    if (sl > 0 && sl - Ask < stopLevel_Pts) {
      accepted_price = Ask + stopLevel_Pts;
      Print("WARNING! SELL SL ", sl, ", Ask ", Ask,
            " (SL-Ask = ", NormalizeDouble((sl - Ask) / _Point, _Digits),
            ") WITHIN STOP LEVEL OF ", stopLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
    // FREEZE LEVELS CHECK
    if (tp > 0 && Ask - tp < freezeLevel_Pts) {
      accepted_price = Ask - freezeLevel_Pts;
      Print("WARNING! SELL TP ", tp, ", Ask ", Ask,
            " (Ask-TP = ", NormalizeDouble((Ask - tp) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
    if (sl > 0 && sl - Ask < freezeLevel_Pts) {
      accepted_price = Ask + freezeLevel_Pts;
      Print("WARNING! SELL SL ", sl, ", Ask ", Ask,
            " (SL-Ask = ", NormalizeDouble((sl - Ask) / _Point, _Digits),
            ") WITHIN FREEZE LEVEL OF ", freezeLevel);
      Print("PRICE MODIFIED TO: ", accepted_price);
      return (accepted_price);
    }
  }
  return (accepted_price);
}
