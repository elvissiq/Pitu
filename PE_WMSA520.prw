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
@SINCE 03/04/2024
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
			aAdd(xRet, {"Recalcular Rateio", "", {|| U_fnRateio()}, "Recalcular Rateio"})
		
		EndIf 

	EndIf 

	FWRestArea(aArea)

Return xRet

//----------------------------------------------------------
/*/{PROTHEUS.DOC} fnEstrut
Carrega produtos da estrutura
@OWNER WMS
@VERSION PROTHEUS 12
@SINCE 03/04/2024
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
@SINCE 03/04/2024
/*/
User Function fnRateio()
	Local oModel    := FwModelActive()
	Local oModelD0C := oModel:GetModel("A520D0C")
	Local oView     := FWViewActive()
	Local cLocPad   := ""
	Local nCustUnit	:= 0
	Local nCustoB1	:= 0
	Local nCustoB2	:= 0
	Local nCustTot  := 0
	Local nSomaCust := 0
	Local nY
	
	For nY := 1 To oModelD0C:Length()
		oModelD0C:GoLine(nY)
		IF !oModelD0C:IsDeleted()
			
			cLocPad  := Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_LOCPAD")
			nCustoB1 := Round(Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_CUSTD"),2)
			nCustoB2 := Round(Posicione("SB2",1,xFilial("SB2")+oModelD0C:GetValue("D0C_PRODUT")+cLocPad,"B2_CM1"),2)
			
			If( !Empty(nCustoB2), nCustUnit := nCustoB2 , nCustUnit := nCustoB1 )
			nCustTot += ( nCustUnit * oModelD0C:GetValue("QUANT") )

		EndIF
	Next

	For nY := 1 To oModelD0C:Length()
		oModelD0C:GoLine(nY)
		IF !oModelD0C:IsDeleted()
			
			cLocPad  := Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_LOCPAD")
			nCustoB1 := Round(Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_CUSTD"),2)
			nCustoB2 := Round(Posicione("SB2",1,xFilial("SB2")+oModelD0C:GetValue("D0C_PRODUT")+cLocPad,"B2_CM1"),2)
			
			If( !Empty(nCustoB2), nCustUnit := nCustoB2 , nCustUnit := nCustoB1 )
			
			If nY < oModelD0C:Length()
				nSomaCust += Round(( ( nCustUnit * oModelD0C:GetValue("QUANT") ) / nCustTot ) * 100,2)
				oModelD0C:SetValue("D0C_RATEIO", ( ( nCustUnit * oModelD0C:GetValue("QUANT") ) / nCustTot ) * 100 )
			ElseIF nY == oModelD0C:Length()
				nSomaCust += Round(( ( nCustUnit * oModelD0C:GetValue("QUANT") ) / nCustTot ) * 100,2)
				If nSomaCust == 100
					oModelD0C:SetValue("D0C_RATEIO", ( ( nCustUnit * oModelD0C:GetValue("QUANT") ) / nCustTot ) * 100 )
				ElseIF nSomaCust < 100
					nSomaCust := 100 - nSomaCust
					oModelD0C:SetValue("D0C_RATEIO", ( ( (nCustUnit * oModelD0C:GetValue("QUANT")) / nCustTot ) * 100) + nSomaCust )
				EndIF 
			EndIf 

			oView:Refresh("VA520D0C")
		EndIF
	Next

	If !Empty(oView)
		oView:Refresh()
	EndIf

Return
