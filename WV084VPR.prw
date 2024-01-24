#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOTVS.CH"
#INCLUDE "TOPCONN.CH"
#INCLUDE "TBICONN.ch"
#INCLUDE "FWMVCDEF.ch"

/*/
  @param
  @return N�o retorna nada
  @author Totvs Nordeste (Elvis Siqueira)
  @owner Totvs S/A
  @version Protheus 10, Protheus 11,Protheus 12
  @sample
  		Este Ponto de Entrada permite que a opera��o de um armaz�m receba os produtos unitizados 
        e realize o processo de confer�ncia do recebimento, sem que haja a necessidade de abrir os inv�lucros.
  24/01/2024 - Desenvolvimento da Rotina.
/*/

User Function WV084VPR()

    Local aArea     := GetArea()
    Local lRet      := .T.
    Local aItensUni := {}
    Local cProduto  := PARAMIXB[1]
    Local cLoteCtl  := PARAMIXB[2]
    Local nQtde     := PARAMIXB[3]
    Local cArmazem  := PARAMIXB[4]
    Local cEndereco := PARAMIXB[5]
    Local cOrigem   := PARAMIXB[6]
    Local cTipUni   := PARAMIXB[7] 
    Local cIdUnitiz	:= MV_PAR60
    Local oMntUniItem := WMSDTCMontagemUnitizadorItens():New()

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
                    //oMntUniItem:SetNumLote(cNumLote)
                    oMntUniItem:SetQuant(nQtde)
                    If oMntUniItem:MntPrdUni()
                        // Caso operador tenha sa�do da montagem e n�o tenha gerado Ordem de Servi�o, altera o status para '2=Aguard. Ender'
                        If oMntUniItem:oUnitiz:GetStatus() == "1" //.And. oMntUniItem:oUnitiz:UniHasItem()
                            oMntUniItem:oUnitiz:SetStatus("2") // Aguardando Endere�amento
                            If !oMntUniItem:oUnitiz:UpdStatus()
            //              	WMSVTAviso(WMSV08418, oMntUniItem:oUnitiz:GetErro()) // Erro do objeto
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
                    If lRet
                        lEndereca := .T.
                        oMntUniItem:SetIdUnit("")
                        oMntUniItem:oUnitiz:SetStatus("3")
                    Endif
                Endif
            Endif
        Endif
    Endif
    oMntUniItem:Destroy()

    If !Empty(cIdUnitiz)
        ExecuteSrv(.T.,cIdUnitiz)
    EndIF

    MV_PAR60 := ""

    RestArea(aArea)

Return aItensUni


/*/{Protheus.doc} OSPend
//Fun��o que ir� executar o servi�o do WMS. 
@author Elvis Siqueira
@since 24/01/2024
@version 1.0

@type function
/*/

Static Function ExecuteSrv(lEnd,pIdUnitiz)
    Local aAreaDCF   := DCF->(GetArea())
    Local cAliasDCF  := GetNextAlias()
    Local cStatus    := ""
    Local cSrvVazio  := PadR("", TamSx3("DCF_SERVIC")[1])
    Local cMensagem  := ''
    Local oOrdSerExe := WMSDTCOrdemServicoExecute():New()
    Local oRegraConv := WMSBCCRegraConvocacao():New()
    Local aOrdSerExe := {}
    Local nI         := 0
    Local lAutomato  := .F.
	
    // Verificar data do ultimo fechamento em SX6.
	If MVUlmes() >= dDataBase
		WmsMessage("N�o pode ser digitado movimento com data anterior a �ltima data de fechamento (virada de saldos).",WMSA15005,,,,"Utilizar data posterior ao �ltimo fechamento de estoque (MV_ULMES) / posterior � data do bloqueio de movimentos (MV_DBLQMOV).")
		Return Nil
	EndIf
	If !oOrdSerExe:ChecaPrior()
		WmsMessage(oOrdSerExe:GetErro(),WMSA15013,1)
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
			SELECT DCF.R_E_C_N_O_ RECNODCF
			FROM %Table:DCF% DCF
			WHERE DCF.DCF_FILIAL = %xFilial:DCF%
			AND DCF.DCF_SERVIC BETWEEN %Exp:MV_PAR01% AND %Exp:MV_PAR02%
			AND DCF.DCF_SERVIC <> %Exp:cSrvVazio%
			AND DCF.DCF_STSERV IN ( %Exp:cStatus% )
            AND DCF.DCF_UNITIZ = %Exp:pIdUnitiz%
			AND DCF.%NotDel%
	EndSql
	// Devido processo de execu��o efetuar o disarmtransaction ha situa��es que o cache � limpo
	// e perde-se o cAliasDCF por isso � gerado um vetor de dados para controle
	(cAliasDCF)->(dbEval({|| aAdd( aOrdSerExe,(cAliasDCF)->RECNODCF)}))
	(cAliasDCF)->(dbCloseArea())
	If Empty(aOrdSerExe)	
		RestArea(aAreaDCF)
		Return Nil
	EndIf
	WMSCTPENDU() // Cria as tempor�rias - FORA DA TRANSA��O
	ProcRegua(Len(aOrdSerExe))
	oOrdSerExe:SetArrLib(oRegraConv:GetArrLib())
	For nI := 1 To Len(aOrdSerExe)
		If OSPend(aOrdSerExe[nI]) 
			oOrdSerExe:GoToDCF(aOrdSerExe[nI])
			IncProc(oOrdSerExe:GetServico()+" - "+If(Empty(oOrdSerExe:GetCarga()),Trim(oOrdSerExe:GetDocto())+"/"+Trim(oOrdSerExe:GetSerie()),Trim(oOrdSerExe:GetCarga()))+"/"+Trim(oOrdSerExe:oProdLote:GetProduto()))
			oOrdSerExe:ExecuteDCF()
		Else
			IncProc('Ordem de servi�o ID ' + AllTrim(aOrdSerExe[nI]) + ' j� executada.')
		EndIf
	Next 
	// Verifica as movimenta��es liberadas para verificar se h� reabastecimentos gerados
	oOrdSerExe:ChkOrdReab()
	// O wms devera avaliar as regras para convocacao do servico e disponibilizar os
	// registros do D12 para convocacao
	oRegraConv:LawExecute()	
	// Exibe as mensages de erro na ordem de servi�o
	// Aviso
	If !lAutomato
		oOrdSerExe:ShowWarnig()
		//-- Exibe as mensagens de reabastecimento
		If SuperGetMV('MV_WMSEMRE',.F.,.T.) .And. !Empty(oOrdSerExe:aWmsReab)
			TmsMsgErr(oOrdSerExe:aWmsReab, "Reabastecimentos pendentes:")
		EndIf
		If Len(oOrdSerExe:GetLogSld()) > 0 .And. (oOrdSerExe:HasLogSld() .Or. SuperGetMV('MV_WMSRLSA',.F.,.F.))
			cMensagem := ""
			// Se a impress�o � for�ada, n�o mostra a mensagem de OS n�o atendida
			If !SuperGetMV('MV_WMSRLSA',.F.,.F.)
				cMensagem := "Existem ordens de servi�o de apanhe que n�o foram totalmente atendidas."+CRLF
			EndIf
			cMensagem += "Deseja imprimir o relat�rio de busca de saldo para o apanhe?"
			If WmsQuestion(cMensagem,WMSA15003)
				WMSR111(oOrdSerExe:GetLogSld())
			EndIf
		EndIf
		If Len(oOrdSerExe:GetLogEnd()) > 0 .And. (oOrdSerExe:HasLogEnd() .Or. SuperGetMV('MV_WMSRLEN',.F.,.F.))
			cMensagem := ""
			// Se a impress�o � for�ada, n�o mostra a mensagem de OS n�o atendida
			If !SuperGetMV('MV_WMSRLEN',.F.,.F.)
				cMensagem := "Existem ordens de servi�o de endere�amento que n�o foram totalmente atendidas."+CRLF
			EndIf
			cMensagem += "Deseja imprimir o relat�rio de busca de endere�os para a armazenagem?"
			If WmsQuestion(cMensagem,WMSA15004)
				WMSR121(oOrdSerExe:GetLogEnd())
			EndIf
		EndIf
		If Len(oOrdSerExe:GetLogUni()) > 0 .And. (oOrdSerExe:HasLogUni() .Or. SuperGetMV('MV_WMSRLEN',.F.,.F.))
			cMensagem := ""
			// Se a impress�o � for�ada, n�o mostra a mensagem de OS n�o atendida
			If !SuperGetMV('MV_WMSRLEN',.F.,.F.)
				cMensagem := "Existem ordens de servi�o de endere�amento unitizado que n�o foram totalmente atendidas."+CRLF 
			EndIf
			/*
            cMensagem += "Deseja imprimir o relat�rio de busca de endere�os para a armazenagem unitizada?"
			If WmsQuestion(cMensagem,WMSA15004)
				WMSR125(oOrdSerExe:GetLogUni())
			EndIf
            */
		EndIf
	EndIf
	WMSDTPENDU() // Destroy as tempor�rias - FORA DA TRANSA��O
	RestArea(aAreaDCF)
Return lEnd

/*/{Protheus.doc} OSPend
//Fun��o que verifica se a OS ainda est� pendente. 
Na tela principal a OS est� pendente e � adicionada ao array. Entretanto, durante a execu��o de outra OS
esta pode ter sido aglutinada, fazendo com que o status mude e n�o haja mais necessidade de execut�-la.
O objetivo � evitar de fazer o LoadData da classe WMSDTCOrdemServico para essas OS's, e otimizar o
processamento.
@author Elvis Siqueira
@since 24/01/2024
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
