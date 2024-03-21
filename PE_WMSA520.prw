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
@SINCE 19/03/2024
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
@SINCE 19/03/2024
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

	While ! (_cAlias)->(Eof())
		
		If IntWMS((_cAlias)->G1_COMP)
			oSeqAbast:SetArmazem(oModelD0A:GetValue('D0A_LOCAL'))
			oSeqAbast:SetProduto((_cAlias)->G1_COMP)
			oSeqAbast:SetEstFis(oEstEnder:oEndereco:GetEstFis())
			If !oSeqAbast:LoadData(2)
				
				FWAlertHelp("O produto " + Alltrim((_cAlias)->G1_COMP) + " não possui a estrutura cadastrada do endereço destino informado.",;
							"Informe outro endereço ou cadastre a estrutura para o produto.")
			
			Else 
				oModelD0C:AddLine()
				oModelD0C:SetValue("D0C_PRODUT", (_cAlias)->G1_COMP )
				oView:Refresh("VA520D0C")
			EndIf
		EndIF 

	(_cAlias)->(DBSkip())
	EndDo  

	(_cAlias)->(DbCloseArea()) 

	U_fnRateio() //Calcula o rateio dos itens da estrutura

	If !Empty(oView)
		oView:Refresh()
	EndIf

	oSeqAbast:Destroy()
Return

//----------------------------------------------------------
/*/{PROTHEUS.DOC} fnRateio
Calcula o rateio dos itens da estrutura
@OWNER WMS
@VERSION PROTHEUS 12
@SINCE 19/03/2024
/*/
User Function fnRateio()
	Local oModel    := FwModelActive()
	Local oModelD0A := oModel:GetModel("A520D0A")
	Local oModelD0C := oModel:GetModel("A520D0C")
	Local oView     := FWViewActive()
	Local nQtdDemon	:= oModelD0A:GetValue("D0A_QTDMOV")
	Local cLocPad   := ""
	Local nUprc		:= 0
	Local aSalAtu	:= {}
	Local nPreco	:= 0
	Local nQuant	:= 0
	Local nTotal	:= 0
	Local dDatFech	:= GetMv("MV_ULMES")
	Local nCustD	:= 0
	Local nTotItem  := 0
	Local nY

	For nY := 1 To oModelD0C:Length()
		oModelD0C:GoLine(nY)
		If !oModelD0C:IsDeleted()
			++nTotItem
		EndIF 
	Next 

	For nY := 1 To oModelD0C:Length()

		oModelD0C:GoLine(nY)
		
		IF !oModelD0C:IsDeleted()

			cLocPad := Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_LOCPAD")
			nUprc	:= Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_UPRC")
			nCustD	:= Posicione("SB1",1,xFilial("SB1")+oModelD0C:GetValue("D0C_PRODUT"),"B1_CUSTD")

			If SG1->( dbSeek( xFilial("SG1") + oModelD0A:GetValue("D0A_PRODUT") + oModelD0C:GetValue("D0C_PRODUT") ) )
						
				nQuant := SG1->G1_QUANT * nQtdDemon
				aSalAtu := CalcEst( oModelD0C:GetValue("D0C_PRODUT") , cLocPad , dDatFech+1 )    // Pega o saldo inicial do dia 01 do mes seguinte

				If( !Empty(aSalAtu[2] / aSalAtu[1]) , nPreco := aSalAtu[2] / aSalAtu[1] , nPreco := nUprc )
						
				If(Empty(nPreco),nPreco:=nCustD,.T.)
						
				nTotal += Round( nQuant * nPreco , 2 )

				oModelD0C:SetValue("D0C_RATEIO", Round( ( nTotItem / nTotal ) , 4 ) * 100 )
				oView:Refresh("VA520D0C")
			
			EndIF
		
		EndIF

	Next

	If !Empty(oView)
		oView:Refresh()
	EndIf

Return
