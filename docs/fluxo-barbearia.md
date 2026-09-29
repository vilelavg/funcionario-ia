# Fluxo da Barbearia Navalha de Ouro — v1.0

Documento aprovado em 29/09/2026. Descreve tudo o que o Villa (o Funcionário de IA) faz, do primeiro "oi" ao retorno do cliente.
Cada fluxo tem: gatilho, passo a passo, tabelas lidas (L) e escritas (E), travas e exceções.

## 1. Regras do negócio

| Regra | Valor | Coluna no banco |
| --- | --- | --- |
| Horário de funcionamento | Terça a sábado, 9h às 20h | horarios_funcionamento |
| Antecedência mínima para agendar | 3 horas | empresas.antecedencia_min_minutos = 180 |
| Agendamento máximo à frente | 30 dias | empresas.agenda_max_dias |
| Prazo limite para cancelar ou remarcar | 2 horas antes (sem punição; depois dele o barbeiro é avisado) | empresas.cancelamento_min_minutos |
| Tolerância de atraso | 10 minutos após o horário | empresas.tolerancia_atraso_min |
| Formas de pagamento | Débito, crédito, Pix e dinheiro, pagos direto na barbearia | pagamentos.forma |
| Pagamento antecipado | Só na contratação de plano | assinaturas |
| Nota fiscal ou recibo | Só a pedido, depois do pagamento registrado | documentos_fiscais |
| Desconto | Exatamente o da promoção cadastrada, nem mais nem menos | promocoes |
| Horário de silêncio | Nenhuma mensagem ativa entre 22h e 07h | empresas.silencio_inicio / silencio_fim |
| Mensagens ativas por cliente | No máximo 2 por dia | empresas.envios_ativos_cliente_dia_max |
| Mensagens ativas da barbearia | No máximo 50 por dia | empresas.envios_ativos_dia_max |
| Reativação | Intervalo habitual do cliente; padrão 7 dias; no máximo 3 tentativas | empresas.reativacao_padrao_dias |
| Resumo diário para o dono | 08h | empresas.resumo_diario_hora |
| Retenção de conversas | 12 meses, depois anonimiza | empresas.retencao_dias |
| Tom de voz | Informal, simpático e breve; sem gírias pesadas; poucos emojis | empresas.tom_de_voz |

## 2. Regras de conversa (valem para todos os fluxos)

1. **Apresentar e responder juntos.** Na primeira mensagem, o Villa se apresenta e já responde o que foi perguntado, na mesma mensagem.
2. **Agrupar mensagens seguidas.** Espera cerca de 6 segundos de silêncio antes de responder e junta tudo o que o cliente mandou.
3. **Só fala depois do cliente, dentro da conversa.** Mensagens ativas seguem a política da seção 3.
4. **Nunca pergunta o motivo** de cancelamento ou remarcação.
5. **Humano só a pedido explícito.** Reclamações são atendidas pelo Villa; casos graves geram alerta ao dono, sem transferir.
6. **Nada inventado.** Preço, horário, promoção e motivo de serviço não oferecido vêm sempre do banco.
7. **Opt-out vence tudo.** "Pare", "não quero mais", "sair" encerram qualquer mensagem ativa, na hora.

## 3. Política unificada de contato ativo

Regras globais: horário de silêncio de 22h às 07h; no máximo 2 mensagens ativas por cliente por dia; opt-out vence tudo; **um estado de contato por cliente por vez** (clientes.estado_contato). Se dois estados disputam o mesmo cliente, vale o de maior prioridade.

| Prioridade | Estado | Gatilho | Cadência | Encerra quando |
| --- | --- | --- | --- | --- |
| 1 | lembrete | Horário marcado | 12 h antes + no máximo 2 reforços | Cliente confirma, cancela, remarca ou chega o horário |
| 2 | conversa_pendente | Villa fez uma pergunta e ficou sem resposta | 1 mensagem após 5 min | Cliente responde ou passam 5 min do aviso |
| 3 | follow_up | Mostrou interesse e não confirmou | A cada 4 h, no máximo 3 | Agenda, recusa ou acaba a cota |
| 4 | pos_cancelamento_ou_falta | Cancelou sem remarcar, ou faltou (confirmado pelo barbeiro) | 1 contato após 3 dias | Remarca ou não responde |
| 5 | pos_atendimento | Pagamento registrado | Agradecimento + link de avaliação 1 h depois | Envio feito; passa para reativação |
| 6 | reativacao | Passou o intervalo habitual do cliente | Até 3 tentativas: no intervalo, +3 dias, +7 dias | Agenda ou acaba a cota |

Mensagem que cairia no horário de silêncio é reprogramada para 07h do dia seguinte. Fora da janela de 24 h, só sai com template aprovado.

---

## F01 — Primeiro contato
- **Gatilho:** número que nunca falou com a barbearia.
- **Passos:** 1) cria o cliente; 2) responde numa única mensagem: apresentação curta + resposta ao que foi perguntado + uma linha com o link de privacidade; 3) registra o consentimento de privacidade.
- **L/E:** E clientes, conversas, mensagens, consentimentos.
- **Travas:** a linha de apresentação e a de privacidade são textos fixos.
- **Exceções:** se for só "oi", responde com apresentação + oferta de ajuda (serviços, preços ou agendar).

## F02 — Consultas
- **Gatilho:** pergunta sobre serviço, preço, formas de pagamento, planos, endereço ou funcionamento.
- **Passos:** 1) classifica; 2) consulta o banco; 3) responde com o dado exato; 4) oferece agendar.
- **L/E:** L servicos, planos, horarios_funcionamento, empresas, servicos_nao_oferecidos.
- **Travas:** valores sempre de servicos.preco_centavos e planos.preco_centavos.
- **Serviço não oferecido:** informa que não faz, dá o motivo cadastrado pelo dono (servicos_nao_oferecidos.motivo, no máximo 200 caracteres) e, se houver, sugere a alternativa cadastrada. Serviço desconhecido e sem motivo cadastrado → "esse serviço a gente não faz aqui" + oferta do que existe. Nunca inventa motivo.

## F03 — Agendamento
- **Gatilho:** cliente quer marcar.
- **Caminho A — pediu um horário:** 1) verifica serviço, dia e hora; 2) se estiver livre e **tudo foi dito explicitamente**, reserva direto e manda a confirmação; 3) se o Villa precisou deduzir algo (qual sexta, qual barbeiro, qual serviço), confirma com uma pergunta de sim ou não antes de reservar; 4) se estiver ocupado, oferece 4 opções: 2 antes e 2 depois do horário pedido.
- **Caminho B — não pediu horário:** oferece até 4 horários livres a partir da preferência de dia ou turno.
- **Regras das 4 opções:** respeitam antecedência de 3 h, funcionamento, bloqueios e profissional que faz o serviço. Sem 2 horários antes (início do dia), completa com horários depois ou com o dia seguinte.
- **Depois de reservar:** grava, cria evento no Google Agenda, confirma com data, hora, barbeiro, valor e endereço, e pergunta se quer lembrete (opt-in).
- **Cliente com plano ativo:** informa que o corte está incluso e quantos restam no mês.
- **L/E:** L servicos, profissionais, profissional_servicos, horarios_funcionamento, bloqueios_agenda, agendamentos, assinaturas. E agendamentos, consentimentos, log_acoes.
- **Travas:** trava sem_conflito no banco.
- **Exceções:** horário ocupado entre a oferta e a reserva → oferece as próximas opções.

## F04 — Remarcação
- **Gatilho:** cliente com horário futuro pede para mudar. Nunca pergunta o motivo.
- **Passos:** 1) localiza o agendamento (se houver mais de um, pergunta qual); 2) com horário pedido → Caminho A do F03; sem horário → oferece primeiro horários livres do **mesmo dia** que respeitem a antecedência, depois outros dias; 3) troca atômica (cria o novo e cancela o antigo na mesma transação); 4) atualiza o Google Agenda; 5) confirma.
- **Depois do prazo limite:** remarca normalmente e avisa o barbeiro na hora.

## F05 — Cancelamento
- **Gatilho:** cliente pede para cancelar. Nunca pergunta o motivo.
- **Passos:** 1) localiza; 2) confirma; 3) marca cancelado; 4) remove do Google Agenda; 5) cancela lembretes; 6) oferece remarcar; 7) se não remarcar, lamenta a ausência de forma leve ("poxa, que pena! quando quiser, é só chamar") e entra em pos_cancelamento_ou_falta.
- **Depois do prazo limite:** cancela normalmente, sem punição, e avisa o barbeiro na hora.
- **Diferença importante:** cancelar não é opt-out. Só "pare" / "não quero mais mensagens" encerra os contatos.

## F06 — Registro de pagamento (barbeiro)
- **Gatilho:** barbeiro diz "Ei, Villa, o João pagou no débito" (voz, Fase 3.5) ou manda por texto no WhatsApp (Fase 2).
- **Passos:** 1) confirma que o número é de um profissional cadastrado; 2) identifica o cliente pela agenda do momento daquele barbeiro; 3) usa o valor do serviço agendado, a menos que o barbeiro informe outro; 4) registra forma e valor; 5) marca o agendamento como concluído; 6) responde "registrado: João, corte, R$ 45, débito".
- **L/E:** L profissionais, agendamentos, servicos. E pagamentos, agendamentos, log_acoes.
- **Travas:** só números de profissionais; forma limitada a débito, crédito, Pix ou dinheiro; chave de idempotência contra registro duplicado.
- **Exceções:** nome ambíguo sem agendamento que desempate → pergunta ao barbeiro qual cliente. Cliente sem agendamento (encaixe não registrado) → cria o encaixe e registra.

## F07 — Nota fiscal ou recibo
- **Gatilho:** pedido do cliente ao barbeiro ("Ei, Villa, nota do João") ou do cliente no WhatsApp, sempre depois do pagamento registrado.
- **Passos:** 1) confirma o pagamento; 2) pergunta se é nota ou recibo; 3) para nota, pede CPF só nesse momento; 4) gera; 5) envia o PDF ao cliente.
- **L/E:** L pagamentos, clientes. E documentos_fiscais.
- **Travas:** um documento de cada tipo por pagamento; sem pagamento registrado, não gera.
- **Exceções:** emissor fora do ar → avisa o cliente que vai chegar em breve, tenta de novo em 30 min e alerta o dono se falhar 3 vezes.

## F08 — Lembretes
- **Gatilho:** agendador interno.
- **Passos:** 1) 12 h antes, envia lembrete pedindo confirmação; 2) sem resposta, reforço 6 h antes do horário; 3) sem resposta, último reforço 1 h antes do prazo limite (3 h antes do horário); 4) confirmou → para.
- **Silêncio:** lembrete que cairia entre 22h e 07h vai para 07h. Se 07h já passou do horário do reforço seguinte, pula para o reforço.
- **Agendado com menos de 12 h:** a confirmação do agendamento conta como lembrete; só sai o reforço de 1 h antes do prazo, se ainda couber.
- **L/E:** L agendamentos, consentimentos. E envios_ativos, clientes.estado_contato.
- **Travas:** sem opt-in de lembrete, não envia; no máximo 1 lembrete + 2 reforços por agendamento.

## F09 — Falta
- **Gatilho:** barbeiro confirma "o João não veio" (voz ou texto), depois dos 10 minutos de tolerância.
- **Passos:** 1) marca faltou com o barbeiro como autor; 2) envia ao cliente mensagem leve, sem punição, avisando que o horário passou; 3) oferece remarcar; 4) entra em pos_cancelamento_ou_falta.
- **Travas:** o banco recusa falta sem barbeiro autor. **Nunca** há mensagem de falta automática.

## F10 — Conversa pendente e agrupamento
- **Gatilho:** o Villa fez uma pergunta e o cliente sumiu por 5 minutos.
- **Passos:** 1) uma única mensagem gentil retomando o ponto; 2) sem retorno, não manda mais nada naquela conversa; 3) se havia interesse em agendar, entra em follow_up.
- **Não dispara** quando a conversa terminou naturalmente ("valeu, até sexta").

## F11 — Follow-up de interesse
- **Gatilho:** cliente mostrou interesse (perguntou preço, pediu horários) e não confirmou.
- **Passos:** até 3 mensagens, a cada 4 h, dentro do horário permitido; sempre educadas e diferentes entre si.
- **Encerra:** agendou, disse que não quer, ou acabou a cota. Dentro da janela de 24 h, sai como mensagem comum, sem template.

## F12 — Pós-cancelamento ou falta
- **Gatilho:** cancelou sem remarcar, ou falta confirmada.
- **Passos:** 1 contato leve 3 dias depois, oferecendo horários. Sem resposta, passa para reativação no ciclo normal.

## F13 — Pós-atendimento
- **Gatilho:** pagamento registrado.
- **Passos:** 1 h depois, agradecimento + link de avaliação do Google para **todos** os clientes (sem filtrar por satisfação, conforme a política do Google). Depois, passa para reativação.
- **Travas:** nunca oferece brinde em troca de avaliação.

## F14 — Reativação
- **Gatilho:** passou o intervalo habitual do cliente (média entre as últimas visitas); sem histórico, 7 dias.
- **Passos:** até 3 tentativas: no intervalo, +3 dias e +7 dias. Oferece horários e, se houver, promoção ativa.
- **Encerra:** agendou, recusou, opt-out ou acabou a cota. O ciclo recomeça na próxima visita.
- **Travas:** opt-in de marketing obrigatório; limites diários.

## F15 — Planos
- **Gatilho:** cliente pergunta por plano, ou o Villa oferece a quem visita com frequência (só se o dono tiver cadastrado planos).
- **Passos:** 1) apresenta os planos ativos com preço e benefícios cadastrados; 2) interesse → informa que o pagamento é antecipado, na barbearia; 3) barbeiro registra o pagamento (F06) → assinatura ativada com os cortes incluídos; 4) a cada corte, desconta do saldo; 5) 3 dias antes de vencer, avisa o cliente; 6) venceu sem renovação → assinatura vencida, volta ao preço normal.
- **L/E:** L planos. E assinaturas, pagamentos.
- **Travas:** uma assinatura ativa por cliente; o banco recusa usar mais cortes que o incluído.

## F16 — Reclamações e transferência
- **Reclamação:** o Villa segue atendendo, com atenção e sem discutir. Nunca promete dinheiro, desconto fora da promoção ou reembolso.
- **Alerta ao dono (sem transferir):** machucado, reação a produto, pedido de reembolso, ameaça de processo, ofensa grave.
- **Transferência:** só com pedido explícito ("quero falar com uma pessoa"). Marca a conversa como humano, envia resumo de 3 linhas ao dono e avisa o cliente. Fora do horário, informa quando a equipe retorna.

## F17 — Opt-out
- **Gatilho:** "pare", "sair", "não quero mais mensagens".
- **Passos:** registra consentimentos de marketing e lembrete como falsos, cancela envios pendentes, zera o estado de contato e confirma. Efeito em até 1 minuto.

## F18 — Exclusão de dados (LGPD)
- **Gatilho:** pedido explícito do próprio cliente, pelo número dele.
- **Passos:** 1) informa as consequências (plano encerrado, horários cancelados); 2) confirma; 3) executa sem aprovação do dono; 4) avisa o barbeiro.
- **O que fica:** pagamentos e documentos fiscais, por obrigação legal, sem dados além do necessário.

## F19 — Assistente do dono e comandos do barbeiro
Tudo pelo WhatsApp, por texto ou áudio (e por voz no local, na Fase 3.5).

| Comando ou recurso | Quem pode | Confirmação |
| --- | --- | --- |
| Registrar pagamento, encaixe, falta, pedir nota/recibo | Dono e barbeiros | Resposta com o resumo do registro |
| Bloquear agenda (folga, almoço, feriado) | Dono e o próprio barbeiro | Sim |
| "O Diego não vem hoje" → avisa os clientes e oferece remarcar | Dono | Sim |
| Faturamento, relatórios, lista de faltas | Só o dono | — |
| Cadastrar promoção, plano, serviço não oferecido | Só o dono | Sim |
| Pausar e reativar o Villa | Só o dono | Sim |
| Resumo diário às 08h (agenda do dia, livres, faturamento de ontem) | Só o dono | Automático |
| Relatório semanal em imagem ou PDF | Só o dono | Automático |
| Alertas (reclamação grave, exclusão de dados, cancelamento fora do prazo) | Dono | Automático |

**Travas:** número não cadastrado não executa nada, mesmo dizendo ser o dono; consultas pré-definidas, sem acesso livre ao banco.
