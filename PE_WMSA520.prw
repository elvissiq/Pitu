#Include 'Protheus.ch'
#Include "Totvs.ch"
#Include "TBICONN.ch"
#INCLUDE "topconn.ch"
#Include 'FWMVCDef.ch'

//----------------------------------------------------------
/*/{PROTHEUS.DOC} WMSA520
Ponto de entrada na rotina Troca de Produto WMS
@OWNER WMS
@VERSION PROTHEUS 12
@SINCE 01/04/2024
/*/
User Function WMSA520()

	Local aParam   := PARAMIXB
	Local xRet     := .T.
	Local oObj     := Nil
	Local aArea    := FWGetArea()
	Local cIdPonto := ""
	Local cIdModel := ""
	Local lIsGrid  := .F.
	Local nOpc

	If (aParam <> NIL)
		oObj := aParam[1]
		cIdPonto := aParam[2]
		cIdModel := aParam[3]
		lIsGrid  := (Len(aParam) > 3)
		nOpc := oObj:GetOperation() 
		
		If cIdPonto == 'BUTTONBAR' .And. cValToChar(nOpc) $("1,3,4")

			xRet := {}
			aAdd(xRet, {"Carrega Estrutura", "", {|| U_fnEstrut()}, "Carrega Estrutura"})
			//aAdd(xRet, {"Recalcular Rateio", "", {|| U_fnRateio()}, "Recalcular Rateio"})
		
		EndIf 

	EndIf 

	FWRestArea(aArea)

Return xRet

//----------------------------------------------------------
/*/{PROTHEUS.DOC} fnEstrut
Carrega produtos da estrutura
@OWNER WMS
@VERSION PROTHEUS 12
@SINCE 01/04/2024
/*/
User Function fnEstrut()
	Local oModel    := FwModelActive()
	Local oModelD0A := oModel:GetModel("A520D0A")
	Local oModelD0C := oModel:GetModel("A520D0C")
	Local oView     := FWViewActive()
	Local cQry      := ""
	Local _cAlias   := GetNextAlias()
	Local oSeqAbast := WMSDTCSequenciaAbastecimento():New()

	cQry := " SELECT * FROM " + RetSQLName('SG1') + " "
	cQry += " WHERE D_E_L_E_T_ <> '*' "
	cQry += " AND G1_FILIAL = '" + FWxFilial("SG1") + "' "
	cQry += " AND G1_COD = '" + oModelD0A:GetValue("D0A_PRODUT") + "' "
	TCQuery cQry New Alias &_cAlias

	oModelD0C:ClearData(.T.)

	While ! (_cAlias)->(Eof())

		If IntWMS((_cAlias)->G1_COMP)

			oModelD0C:AddLine()
			oModelD0C:SetValue("D0C_PRODUT", (_cAlias)->G1_COMP )
			oModelD0C:SetValue("QUANT", ( (_cAlias)->G1_QUANT * oModelD0A:GetValue("D0A_QTDMOV") )  )
			oModelD0C:GoLine(1)
			oView:Refresh("VA520D0C")

		EndIF 

	(_cAlias)->(DBSkip())
	EndDo  

	(_cAlias)->(DbCloseArea()) 

	U_fnRateio() //Calcula o rateio dos itens da estrutura

	If !Empty(oView)
		oModelD0C:GoLine(1)
		oView:Refresh()
	EndIf

	oSeqAbast:Destroy()
Return

//----------------------------------------------------------
/*/{PROTHEUS.DOC} fnRateio
Calcula o rateio dos itens da estrutura
@OWNER WMS
@VERSION PROTHEUS 12
@SINCE 01/04/2024
/*/
User Function fnRateio()
	Local oModel    := FwModelActive()
	Local oModelD0C := oModel:GetModel("A520D0C")
	Local oView     := FWViewActive()
	Local nQtdItens := 0
	Local nY

	/*
	Local nPrcPai	:= 0
	Local nPrcFilh	:= 0
	Local cLocPad   := ""
	Local nUPrcPai	:= 0
	Local nUPrcFilh	:= 0
	Local oModelD0A := oModel:GetModel("A520D0A")
	Local aSalPai	:= {}
	Local aSalFilho	:= {}
	Local dDatFech	:= GetMv("MV_ULMES")
	Local nCustPai	:= 0
	Local nCusFilho	:= 0
	Local nCustTotF	:= 0
	*/

	/*
	// Custo do produto principal (Pai)
	cLocPad := Posicione("SB1",1,xFilial("SB1")+oModelD0A:GetValue("D0A_PRODUT"),"B1_LOCPAD")
	nUPrcPai := Posicione("SB1",1,xFilial("SB1")+oModelD0A:GetValue("D0A_PRODUT"),"B1_UPRC")
	nCustPai := Posicione("SB1",1,xFilial("SB1")+oModelD0A:GetValue("D0A_PRODUT"),"B1_CUSTD")

	aSalPai := CalcEst( oModelD0A:GetValue("D0A_PRODUT") , cLocPad , dDatFech+1 )    // Pega o saldo inicial do dia 01 do mes seguinte do produto pai
	If( !Empty(aSalPai[2] / aSalPai[1]) , nPrcPai := aSalPai[2] / aSalPai[1] , nPrcPai := nUPrcPai )					
	If(Empty(nPrcPai),nPrcPai:=nCustPai,.T.)

	// Soma o custo dos produtos da estrutura
	For nY := 1 To oModelD0C:Length()
		oModelD0C:GoLine(nY)
		IF !oModelD0C:IsDeleted()
			cLocPad := Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_LOCPAD")
			nUPrcFilh := Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_UPRC")
			nCusFilho := Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_CUSTD")
						
			aSalFilho := CalcEst( oModelD0C:GetValue("D0C_PRODUT") , cLocPad , dDatFech+1 )
			If( !Empty(aSalFilho[2] / aSalFilho[1]) , nPrcFilh := aSalFilho[2] / aSalFilho[1] , nPrcFilh := nUPrcFilh )
			If(Empty(nPrcFilh),nPrcFilh:=nCusFilho,.T.)

			nQtdItens += oModelD0C:GetValue("QUANT")
			nCustTotF += nCusFilho
		EndIF
	Next
	*/
	
	For nY := 1 To oModelD0C:Length()
		oModelD0C:GoLine(nY)
		IF !oModelD0C:IsDeleted()
			nQtdItens += oModelD0C:GetValue("QUANT")
		EndIF
	Next

	For nY := 1 To oModelD0C:Length()
		oModelD0C:GoLine(nY)
		IF !oModelD0C:IsDeleted()
			oModelD0C:SetValue("D0C_RATEIO", Round( ( oModelD0C:GetValue("QUANT") / nQtdItens ), 4 ) * 100 )
			oView:Refresh("VA520D0C")
		EndIF
	Next

	If !Empty(oView)
		oView:Refresh()
	EndIf

Return
