#include "Totvs.ch"

//----------------------------------------------------------------------
/*/{PROTHEUS.DOC} ValidUni
	Função para validação a Etiqueta de Unitizador preenchido no campo D3_XPALETE
	@OWNER Pitu
	@VERSION PROTHEUS 12
	@SINCE 03/04/2024
	@Valida Etiqueta
/*/

User Function ValidUni(cNumUnit)
	Local lRet  := .F.
	Local aArea := FWGetArea()

	dbSelectArea("D0Y")

	If ! D0Y->(MSSeek(xFilial("D0Y")+cNumUnit))
		lRet := .T.
	Else
		FWAlertError("Etiqueta de Unitizador já existe na D0Y, informe um código que não exista.","Valida Unitizador - ValidUni.prw")
	EndIF 
	
	FWRestArea(aArea)

Return(lRet)
