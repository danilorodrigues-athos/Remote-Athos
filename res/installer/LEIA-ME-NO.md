# NÓ — suporte local (rede interna, com ou sem internet)

Build: commit `a45d697c5` (branch `master`).
Executável: `NO.exe`. Perfil em `%APPDATA%\NO` — não conflita com o RustDesk instalado.

## O que mudou neste build

- **Marca NÓ**: logo novo (N com nó e ondas), título da janela, ícone do app/bandeja
  e metadados do executável. Todo o nome ATHOS e o arqueiro foram removidos.
- **Atualizações offline (L3)**: pasta compartilhada com `no-version.json`; o app
  compara a versão e mostra o pacote disponível.
- **Instalador (L4)**: `Instalar-NO.ps1` copia para `Program Files\NO`, cria atalhos,
  libera a porta 21118 e instala o serviço do Windows.
- **Renomeação (L4)**: serviço, pipe, pasta de configuração e regras de firewall
  agora usam `NO`.
- **Cards de atualização/instalação do upstream desativados no Windows**: a
  atualização oficial do RustDesk não aparece; use **Clientes → Atualizações** (L3).
- **Logo compacto**: o N estilizado forma a própria palavra NÓ, sem repetir a letra.
- **Janela de conexão NÓ**: card do cliente e permissões com o visual da marca,
  mantendo só o que é útil — teclado, clipboard, arquivos, reiniciar, bloquear
  entrada e privacidade. Na conexão remota, chat, áudio e gravação não aparecem.
- **Escanear rede**: ignora os IPs da própria máquina e corrige o filtro de MAC.
- Mantidos: catálogo de clientes, online/offline, hostname com auto-correção de IP,
  histórico, senhas com DPAPI, modo suporte e diagnóstico de firewall.

## Instalação recomendada (máquina controlada)

1. Copie esta pasta para a máquina.
2. Clique com o botão direito em `Instalar-NO.ps1` → **Executar com PowerShell**
   (aceite o UAC).
   - O script copia para `C:\Program Files\NO`, cria atalhos, libera a porta 21118
     e solicita a instalação do serviço.
   - Se o NÓ abrir sozinho ao final da instalação, feche essa janela e abra pelo
     atalho. O atalho inicia o app **sem** privilégios de administrador.
3. Abra o NÓ e confira no card **"Este dispositivo"**:
   - **Serviço: Ativo** (se aparecer **Instalar**, clique e aceite o UAC).
   - **Rede**: o instalador já criou as regras para Domínio, Particular e Público.
     Se aparecer **Pública**, é só o perfil da rede (comum em VPN); a porta 21118
     continua liberada. **Aplicar** recria as regras e não é obrigatório.
4. Defina uma **senha permanente** em **Configurações → Segurança**.
5. No roteador, faça uma **reserva DHCP por MAC** para o IP não mudar.

## Modo portátil (sem instalar)

1. Execute `NO.exe`.
2. No aviso do Windows, use **Mais informações → Executar assim mesmo**.
3. Para acesso sem abrir o app, clique em **Serviço → Instalar**.
   - O serviço aponta para a pasta atual; não mova a pasta depois de instalar.

## Desinstalação

1. Clique com o botão direito em `Desinstalar-NO.ps1` → **Executar com PowerShell**
   (aceite o UAC).
2. O script remove o serviço, `C:\Program Files\NO`, as regras de firewall e os
   atalhos.
3. `%APPDATA%\NO` (ID, senha, catálogo e pasta de atualizações) é **preservado**.
   Para apagar tudo, exclua essa pasta manualmente.

## Atualizações offline (L3)

1. Na máquina controladora, abra **Clientes → Atualizações**.
2. Escolha a pasta compartilhada (ex.: `\\servidor\atualizacoes` ou `C:\NO\updates`).
3. Coloque na pasta o manifesto `no-version.json` e o ZIP do pacote:

   ```json
   {
     "version": "1.5.2",
     "file": "NO-MVP-1.5.2.zip",
     "notes": "Correções e melhorias."
   }
   ```

   Use `modelo-no-version.json` como base.
4. Clique em **Verificar agora**. Se a versão for maior que a atual, o app mostra o
   pacote e as notas.
5. Para atualizar: feche o NÓ, substitua os arquivos (ou rode o instalador) e abra
   de novo. O catálogo e as senhas ficam em `%APPDATA%\NO` e são preservados.

## Renomeação e assinatura (L4)

- Executável entregue: `NO.exe`; serviço, pipe e configuração: `NO`.
- O MSI gerado pelo build continua sendo o do upstream RustDesk e **não é
  distribuído**. Use o ZIP portátil + `Instalar-NO.ps1`.
- **Assinatura de código**: este build não tem certificado. Para assinar, é preciso
  um certificado Authenticode e configurar os secrets de assinatura no workflow.
  Sem isso, o Windows/SmartScreen mostra "editor desconhecido".
- Identificadores internos `rustdesk` (DLL, crate, AppID) permanecem; eles não
  aparecem na interface.

## Migração do ATHOSDESK

Esta versão usa o perfil novo `%APPDATA%\NO`. O catálogo antigo não é importado
automaticamente. Se você já cadastrou clientes no ATHOSDESK:

1. Abra o pacote antigo e use **Clientes → Exportar**.
2. No NÓ, use **Clientes → Importar** e escolha o JSON exportado.
   As senhas continuam legíveis nesta mesma máquina (DPAPI).

## Checklist de teste

- [ ] Janela abre com título **NÓ** e logo NÓ.
- [ ] Ícone da janela/bandeja é o NÓ (não o arqueiro).
- [ ] Card "Este dispositivo" mostra IP, serviço e rede.
- [ ] Serviço instala e a máquina fica acessível após reiniciar.
- [ ] Diagnóstico de rede aplica as regras do firewall.
- [ ] Modo suporte mostra ID/IP/senha em tamanho legível.
- [ ] Catálogo mostra online/offline e "vista por último".
- [ ] Hostname corrige o IP sozinho quando o DHCP muda.
- [ ] Escanear rede não lista a própria máquina.
- [ ] Histórico registra data/hora e duração.
- [ ] Atualizações: escolher pasta, verificar versão e abrir o pacote.
- [ ] Janela de conexão mostra o card NÓ, o status e só as permissões úteis.
- [ ] Instalador copia para Program Files e cria atalhos.
- [ ] Sessão por IP direto funciona sem internet.
- [ ] Mouse, teclado, H.264 e área de transferência.

## Se não conectar

- Confira se a máquina controlada está **ligada** e com o **serviço** instalado.
- **Rede: Pública** não bloqueia: as regras do instalador valem para os três perfis.
  Se o botão **Aplicar** aparecer, ele recria as regras (aceite o UAC).
- Confira a reserva de IP no roteador.
- Teste a porta: `Test-NetConnection <IP> -Port 21118`.

## Segurança

- As senhas do catálogo são criptografadas com DPAPI do Windows, inclusive no
  arquivo de backup. O backup restaurado em outra máquina não revela as senhas;
  cadastre-as de novo lá.
- Use uma senha permanente forte por máquina.
- **Nunca exponha a porta 21118 na internet.** Para acesso externo, use
  WireGuard/Tailscale no roteador.
- Acompanhe os patches de segurança do RustDesk upstream.
