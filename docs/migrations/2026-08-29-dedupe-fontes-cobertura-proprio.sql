-- Bug real achado ao vivo (2026-08-29): garanhões do tipo "Próprio" apareciam
-- duplicados (2-3x) na tela de Cruzamentos (modo rápido e inteligente) da Cabanha
-- Mãe de Deus — não era só exibição, eram linhas de verdade duplicadas em
-- fontes_cobertura (mesmo garanhao_nome + ciclo + tipo='proprio' + status).
--
-- Causa: renderPlanejadorReprodutivo() cria a fonte "Próprio" automaticamente pro
-- ciclo, checando duplicata só no array local em memória (fontesCobertura) antes
-- de disparar o POST assíncrono. Se a tela renderizar de novo (navegação rápida,
-- troca de aba) antes desse POST confirmar e antes do array local refletir o
-- id novo, a checagem local não encontra a fonte (que já existe no banco, só
-- ainda sem confirmação local) e cria outra -- corrida clássica de
-- check-then-act sem trava no servidor.
--
-- Esta migration: (1) limpa as duplicatas já existentes em todos os cab_*
-- provisionados, mantendo sempre a mais antiga (criado_em) e repontando
-- qualquer acasalamentos.fonte_cobertura_id que apontava pra uma duplicata
-- removida; (2) cria um índice único parcial (ciclo, garanhao_nome) where
-- tipo='proprio' no template e em todos os cab_* -- fecha a corrida de vez,
-- porque agora o PRÓPRIO BANCO recusa a segunda inserção, não só a checagem
-- em memória do cliente (que continua existindo, mas vira só uma otimização,
-- não a única linha de defesa).

do $$
declare
  r record;
begin
  for r in select schema_name from public.tenants where provisionado = true loop

    -- 1) Repontar acasalamentos que referenciavam uma duplicata pra manter a mais antiga
    execute format($f$
      with grupos as (
        select tipo, ciclo, garanhao_nome,
               -- desempate determinístico por id (revisão pós-revisor-isolamento, 2026-08-29):
               -- duplicatas nascidas de corrida têm chance real de empatar em criado_em (mesmo
               -- milissegundo) -- sem um tiebreaker fixo, o UPDATE (passo 1) e o DELETE (passo 2)
               -- poderiam escolher "manter" linhas diferentes pro mesmo grupo em execuções
               -- separadas, deixando um acasalamento apontando pra uma linha recém-apagada.
               (array_agg(id order by criado_em asc nulls last, id asc))[1] as manter,
               array_agg(id) as todos
        from %1$I.fontes_cobertura
        where tipo = 'proprio'
        group by tipo, ciclo, garanhao_nome
        having count(*) > 1
      )
      update %1$I.acasalamentos ac
      set fonte_cobertura_id = g.manter
      from grupos g
      where ac.fonte_cobertura_id = any(g.todos) and ac.fonte_cobertura_id <> g.manter
    $f$, r.schema_name);

    -- 2) Apagar as duplicatas, mantendo só a mais antiga de cada grupo
    execute format($f$
      with grupos as (
        select tipo, ciclo, garanhao_nome,
               (array_agg(id order by criado_em asc nulls last, id asc))[1] as manter
        from %1$I.fontes_cobertura
        where tipo = 'proprio'
        group by tipo, ciclo, garanhao_nome
        having count(*) > 1
      )
      delete from %1$I.fontes_cobertura f
      using grupos g
      where f.tipo = g.tipo and f.ciclo = g.ciclo and f.garanhao_nome = g.garanhao_nome
        and f.id <> g.manter
    $f$, r.schema_name);

    -- 3) Índice único: fecha a corrida no servidor de vez
    execute format(
      'create unique index if not exists idx_fontes_cobertura_proprio_unico on %I.fontes_cobertura (ciclo, garanhao_nome) where tipo = ''proprio''',
      r.schema_name
    );
  end loop;
end $$;

-- Template (public) -- toda cabanha provisionada daqui pra frente já nasce com o índice.
create unique index if not exists idx_fontes_cobertura_proprio_unico on public.fontes_cobertura (ciclo, garanhao_nome) where tipo = 'proprio';
