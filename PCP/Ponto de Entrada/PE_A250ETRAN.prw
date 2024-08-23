#include "Totvs.ch"
#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'
#Include "TBICONN.CH"
#Include "TopConn.ch"

//----------------------------------------------------------------------
/*/{PROTHEUS.DOC} A250ETRAN
	Ponto-de-Entrada: A250ETRAN - Ponto de entrada no apontamento da Produção
	@OWNER Pitu
	@VERSION PROTHEUS 12
	@SINCE 03/04/2024
	@Monta Etiqueta
	Programa Fonte
	MATA250.PRW
/*/

User Function A250ETRAN

	Local aArea     := FWGetArea()
	Local lRet      := .T.
	Local cProduto  := SD3->D3_COD
	Local cArmazem  := SD3->D3_LOCAL
	Local cLoteCTL  := SD3->D3_LOTECTL
	Local cNumLote  := SD3->D3_NUMLOTE
	Local cEndereco := SuperGetMV("MV_XENDPAD",.F.,"DOCAE")
	Local cTipUni   := SuperGetMV("MV_XWMSUNI",.F.,"000001")
	Local cEndDest  := SuperGetMV("MV_XENDDES",.F.,"PRODUCAO")
	Local cIdUnitiz	:= IIF(SD3->(FieldPos("D3_XPALETE")) > 0, IIF(!Empty(Alltrim(SD3->D3_XPALETE)),WmsGerUnit(.F.,.F.,.F.,Alltrim(SD3->D3_XPALETE),cTipUni),WmsGerUnit(.F.,.T.)), WmsGerUnit(.F.,.T.))
	Local cOrigem   := "SC2"
	Local nQtde     := SD3->D3_QUANT
	Local oMntUniItem := WMSDTCMontagemUnitizadorItens():New()
	
	Private cDocumento := ""

	If IntWms(cProduto)
		
		If !Empty(cIdUnitiz) .and. WmsArmUnit(cArmazem)
			oMntUniItem:ClearData()
			oMntUniItem:oUnitiz:SetOrigem(cOrigem)
			oMntUniItem:oUnitiz:SetArmazem(cArmazem)
			oMntUniItem:oUnitiz:SetEnder(cEndereco)
			oMntUniItem:SetIdUnit(cIdUnitiz)
			oMntUniItem:oUnitiz:SetStatus("1") // Em Montagem
			
			If !oMntUniItem:oUnitiz:UniHasItem()
				oMntUniItem:oUnitiz:SetTipUni(cTipUni)
				oMntUniItem:oUnitiz:SetDatIni(dDataBase)
				oMntUniItem:oUnitiz:SetHorIni(Time())
				
				If !oMntUniItem:oUnitiz:UpdStatus()
					oMntUniItem:oUnitiz:SetDatFim(StoD(""))
					oMntUniItem:oUnitiz:SetHorFim("")
					oMntUniItem:SetPrdOri(cProduto)
					oMntUniItem:SetProduto(cProduto)
					oMntUniItem:SetLoteCtl(cLoteCTL)
					oMntUniItem:SetNumLote(cNumLote)
					oMntUniItem:SetQuant(nQtde)
					
					If oMntUniItem:MntPrdUni()
						// Caso operador tenha saído da montagem e não tenha gerado Ordem de Serviço, altera o status para '2=Aguard. Ender'
						
						If oMntUniItem:oUnitiz:GetStatus() == "1" // .And. oMntUniItem:oUnitiz:UniHasItem()
							oMntUniItem:oUnitiz:SetStatus("2")    // Aguardando Endereçamento
							
							If !oMntUniItem:oUnitiz:UpdStatus()
								lRet := .F.
							EndIf
						
						EndIf
					Endif
					
					If lRet .And. oMntUniItem:oUnitiz:GetStatus() == "3"
						lRet := .F.
					EndIf
					
					// Deve validar se o unitizador possui itens
					If lRet .And. !oMntUniItem:oUnitiz:UniHasItem()
						lRet := .F.
					EndIf
					
					lRet := WMSV086END({cIdUnitiz})
	
				Endif
			Endif
		Endif
	Endif

	oMntUniItem:Destroy()

	If !Empty(cIdUnitiz) .and. lRet
		ExecuteSrv(cIdUnitiz,cEndDest)

		If !Empty(cDocumento)
			dbSelectArea("D12")
			D12->(dbSetOrder(5))
			D12->(MSSeek(xFilial()+cDocumento))
			While !Eof() .and. xFilial()+cDocumento == D12->(D12_FILIAL+D12_DOC)
				If D12->D12_STATUS == "4"
						DBGoto(Recno())
						FinalzD12(Recno())
					Exit
				Endif
				dbSkip()
			End
		EndIF

    EndIF

	FWRestArea(aArea)
Return

//--------------------------------------------------------------------------------------------------------------
Static Function ExecuteSrv(pIdUnitiz,cEndDest)
    Local aAreaDCF   := DCF->(GetArea())
    Local cAliasDCF  := GetNextAlias()
    Local cStatus    := ""
    Local cSrvVazio  := PadR("", TamSx3("DCF_SERVIC")[1])
    Local oOrdSerExe := WMSDTCOrdemServicoExecute():New()
    Local oRegraConv := WMSBCCRegraConvocacao():New()
    Local aOrdSerExe := {}
    Local nI         := 0
	
    // Verificar data do ultimo fechamento em SX6.
	If MVUlmes() >= dDataBase
		Return Nil
	EndIf
	If !oOrdSerExe:ChecaPrior()
		Return Nil
	EndIf
	// Status do Servico 1- Nao Executados
	//                   2- Interrompidos
	//                   3- Ja Executados
	//                   4- Aptos a Execucao (Nao Executados e Iterrompidos)
	//                   5- Aptos ao Estorno (Ja Executados e Interrompidos)
	cStatus := "'1','2'"
    MV_PAR01 := ""
    MV_PAR02 := "ZZZ"
	
	cStatus := "%"+cStatus+"%"
	BeginSql Alias cAliasDCF
			SELECT DCF.R_E_C_N_O_ AS RECNODCF, DCF.DCF_DOCTO AS DOCUMENTO
			FROM %Table:DCF% DCF
			WHERE DCF.DCF_FILIAL = %xFilial:DCF%
			AND DCF.DCF_SERVIC BETWEEN %Exp:MV_PAR01% AND %Exp:MV_PAR02%
			AND DCF.DCF_SERVIC <> %Exp:cSrvVazio%
			AND DCF.DCF_STSERV IN ( %Exp:cStatus% )
            AND DCF.DCF_UNITIZ = %Exp:pIdUnitiz%
			AND DCF.%NotDel%
	EndSql

	// Devido processo de execução efetuar o disarmtransaction ha situações que o cache é limpo
	// e perde-se o cAliasDCF por isso é gerado um vetor de dados para controle
	cDocumento := (cAliasDCF)->DOCUMENTO

	(cAliasDCF)->(dbEval({|| aAdd( aOrdSerExe,(cAliasDCF)->RECNODCF)}))
	(cAliasDCF)->(dbCloseArea())

	If Empty(aOrdSerExe)	
		RestArea(aAreaDCF)
		Return Nil
	EndIf

	WMSCTPENDU() // Cria as temporárias - FORA DA TRANSAÇÃO

	ProcRegua(Len(aOrdSerExe))
	oOrdSerExe:SetArrLib(oRegraConv:GetArrLib())
	For nI := 1 To Len(aOrdSerExe)
		If OSPend(aOrdSerExe[nI]) 
			oOrdSerExe:GoToDCF(aOrdSerExe[nI])
		
			DCF->(DbGoTo(aOrdSerExe[nI]))
		
			IncProc(oOrdSerExe:GetServico()+" - "+If(Empty(oOrdSerExe:GetCarga()),Trim(oOrdSerExe:GetDocto())+"/"+Trim(oOrdSerExe:GetSerie()),Trim(oOrdSerExe:GetCarga()))+"/"+Trim(oOrdSerExe:oProdLote:GetProduto()))
			oOrdSerExe:ExecuteDCF()
		Else
			IncProc('Ordem de serviço ID ' + AllTrim(aOrdSerExe[nI]) + ' já executada.')
		EndIf
	Next 

	// Verifica as movimentações liberadas para verificar se há reabastecimentos gerados
	oOrdSerExe:ChkOrdReab()
	
	// O wms devera avaliar as regras para convocacao do servico e disponibilizar os
	// registros do D12 para convocacao
	oRegraConv:LawExecute()	
	
	WMSDTPENDU() // Destroy as temporárias - FORA DA TRANSAÇÃO
	RestArea(aAreaDCF)
Return

/*/{Protheus.doc} OSPend
//Função que verifica se a OS ainda está pendente. 
	Na tela principal a OS está pendente e é adicionada ao array. Entretanto, durante a execução de outra OS
	esta pode ter sido aglutinada, fazendo com que o status mude e não haja mais necessidade de executá-la.
	O objetivo é evitar de fazer o LoadData da classe WMSDTCOrdemServico para essas OS's, e otimizar o
	processamento.
	@author Elvis Siqueira
	@version 1.0
	@type function
/*/

Static Function OSPend(nRecno)
Local cAliasQry := GetNextAlias()
Local lRet := .F.

	BeginSQL Alias cAliasQry
		SELECT Count(1)
		FROM %Table:DCF% DCF
		WHERE DCF.DCF_FILIAL = %xFilial:DCF%
		AND DCF.R_E_C_N_O_ = %Exp:nRecno%
		AND DCF.DCF_STSERV IN ('1','2')
		AND DCF.DCF_STRADI = ' '
		AND DCF.%NotDel%
	EndSql

	lRet := (cAliasQry)->(!Eof())

	(cAliasQry)->(dbCloseArea())

Return lRet

//--------------------------------------------------------------------------------------------------------------
Static Function FinalzD12(nRecno)
  Local aArea    := GetArea()
  Local aAreaD12 := D12->(GetArea())
  Local cAcao    := "1"
  Local cErro    := ""
 
  dbSelectArea("D12")
  D12->(dbGoto(nRecno))

If D12->D12_STATUS == "4"
	Wm332Autom(.T.)
	WmsOpc332("4")
	WmsAcao332(cAcao)
	oModelEnd := FWLoadModel("WMSA332A")
	oModelGrid := oModelEnd:GetModel('D12DETAIL')
	dbSelectArea("D12")
	oModelEnd:SetOperation(MODEL_OPERATION_UPDATE)
	oModelEnd:Activate()
	If oModelEnd:VldData()
		// Se os dados foram validados faz-se a gravação efetiva dos dados (commit)
		oModelEnd:CommitData()
	Else
		aErro := oModelEnd:GetErrorMessage()
		// A estrutura do vetor com erro é:
		// [1] identificador (ID) do formulário de origem
		// [2] identificador (ID) do campo de origem
		// [3] identificador (ID) do formulário de erro
		// [4] identificador (ID) do campo de erro
		// [5] identificador (ID) do erro
		// [6] mensagem do erro
		// [7] mensagem da solução
		// [8] Valor atribuído
		// [9] Valor anterior
		AutoGrLog( "Id do formulário de origem:" + ' [' + AllToChar( aErro[1] ) + ']' )
		AutoGrLog( "Id do campo de origem: " + ' [' + AllToChar( aErro[2] ) + ']' )
		AutoGrLog( "Id do formulário de erro: " + ' [' + AllToChar( aErro[3] ) + ']' )
		AutoGrLog( "Id do campo de erro: " + ' [' + AllToChar( aErro[4] ) + ']' )
		AutoGrLog( "Id do erro: " + ' [' + AllToChar( aErro[5] ) + ']' )
		AutoGrLog( "Mensagem do erro: " + ' [' + AllToChar( aErro[6] ) + ']' )
		AutoGrLog( "Mensagem da solução: " + ' [' + AllToChar( aErro[7] ) + ']' )
		AutoGrLog( "Valor atribuído: " + ' [' + AllToChar( aErro[8] ) + ']' )
		AutoGrLog( "Valor anterior: " + ' [' + AllToChar( aErro[9] ) + ']' )
		cErro := aErro[6]
	EndIf
	oModelEnd:DeActivate()
Endif
RestArea(aAreaD12)
RestArea(aArea)
Return
