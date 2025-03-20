#include <Trade/Trade.mqh>
CTrade obj_Trade;
int handleAO; // variable for storing the handle of the iAO indicator
double AO_data[],AO_color[];
//+------------------------------------------------------------------+
//| Expert initialization function |
//+------------------------------------------------------------------+
int OnInit(){
obj_Trade.SetExpertMagicNumber(115225);
//---create handle of indicator iAO
handleAO = iAO(_Symbol,_Period);
// if the handle is not created
if (handleAO==INVALID_HANDLE){
//tell about the failure
Print("FAILED TO CREATE HANDLE OF THE IAO INDICATOR. REVERTING NOW");
//stop the indicator early

      return (INIT_FAILED);
   }
// sort the data storage arrays as time series
ArraySetAsSeries(AO_data,true);
ArraySetAsSeries(AO_color,true);
//---
return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){
//--- release the indicator handles from pc memory
IndicatorRelease(handleAO);
}


void OnTick(){
//---
double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
// copy data from indicator buffer and store it in a part of the data array
if (CopyBuffer(handleAO,0,0,3,AO_data) < 3){
// if the copying fails, inform about the failure
Print("FAILED TO RETRIEVE ENOUGH DATA FOR FURTHER ANALYSIS. REVERTING");
// quit further calculations and return
return;

}
if (!CopyBuffer(handleAO,1,0,3,AO_color)){return;}
//Print(AO_color[0]," > ",AO_color[1]);
//ArrayPrint(AO_data);
static datetime signalTime = 0;
datetime currTime0 = iTime(_Symbol,_Period,0);
if (AO_color[0]==0 && AO_color[1]==0 && AO_color[2]==1 && signalTime != currTime0 && AO_data[0] >
0){
Print("BUY SIGNAL @ ",TimeCurrent());
signalTime = currTime0;
obj_Trade.Buy(1,_Symbol,Ask,Ask-500*_Point,Ask+500*_Point,MQLInfoString(MQL_PROGRAM_NAME));
}
else if (AO_color[0]==1 && AO_color[1]==1 && AO_color[2]==0 && signalTime != currTime0 && AO_data[
0] < 0){
Print("SELL SIGNAL @ ",TimeCurrent());
signalTime = currTime0;
obj_Trade.Sell(1,_Symbol,Bid,Bid+500*_Point,Bid-500*_Point,MQLInfoString(MQL_PROGRAM_NAME));
}
}