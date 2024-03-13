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
@SINCE 12/03/2024
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
		
		EndIf 

	EndIf 

	FWRestArea(aArea)

Return xRet

//----------------------------------------------------------
/*/{PROTHEUS.DOC} WMSA520
Carrega produtos da estrutura
@OWNER WMS
@VERSION PROTHEUS 12
@SINCE 12/03/2024
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

	If !Empty(oView)
		oView:Refresh()
	EndIf

	oSeqAbast:Destroy()
Return
