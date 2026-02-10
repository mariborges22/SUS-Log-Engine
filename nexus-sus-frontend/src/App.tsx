import { useState } from 'react';
import { Search, Shield, Zap, Info, Activity } from 'lucide-react';

interface SUSData {
    estado: string;
    regiao: string;
    vl_uf: number;
    vl_regiao: number;
    vl_brasil: number;
    dt_competencia: string;
    dt_atualizacao: string;
}

interface SearchResponse {
    status: string;
    data?: SUSData;
    uf?: string;
}

function App() {
    const [uf, setUf] = useState('');
    const [result, setResult] = useState<SearchResponse | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const handleSearch = async (e: React.FormEvent) => {
        e.preventDefault();

        // Front-end Validation (Defense in Depth)
        const sanitizedUF = uf.trim().toUpperCase();
        if (!/^[A-Z]{2}$/.test(sanitizedUF)) {
            setError('Por favor, insira um estado válido (2 letras).');
            return;
        }

        setError(null);
        setLoading(true);

        try {
            const response = await fetch(`/api/search?estado=${sanitizedUF}`);
            if (!response.ok) {
                if (response.status === 429) throw new Error('Muitas buscas em pouco tempo. Aguarde.');
                throw new Error('Falha na comunicação com o servidor.');
            }
            const data: SearchResponse = await response.json();
            setResult(data);
        } catch (err: any) {
            setError(err.message);
            setResult(null);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="card glass">
            <header style={{ textAlign: 'center', marginBottom: '40px' }}>
                <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', marginBottom: '12px' }}>
                    <Zap size={32} color="#00f2fe" fill="#00f2fe" />
                    <h1 style={{ fontSize: '2rem', fontWeight: 700, letterSpacing: '-1px' }}>NEXUS<span style={{ color: '#00f2fe' }}>-SUS</span></h1>
                </div>
                <p style={{ color: 'var(--text-dim)', fontSize: '0.9rem' }}>Busca Ultra-Rápida em Memória O(1)</p>
            </header>

            <form onSubmit={handleSearch} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{ position: 'relative' }}>
                    <Search size={18} style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-dim)' }} />
                    <input
                        type="text"
                        placeholder="Digite o Estado (ex: SP)"
                        maxLength={2}
                        value={uf}
                        onChange={(e) => setUf(e.target.value.toUpperCase())}
                        style={{ width: '100%', paddingLeft: '48px' }}
                    />
                </div>
                <button type="submit" disabled={loading}>
                    {loading ? 'BUSCANDO...' : 'PESQUISAR'}
                </button>
            </form>

            {error && (
                <div style={{ marginTop: '20px', color: 'var(--error)', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.9rem' }}>
                    <Info size={16} /> {error}
                </div>
            )}

            {result && result.status === 'success' && result.data && (
                <div className="result-item">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                        <h2 style={{ fontSize: '1.5rem', fontWeight: 600 }}>{result.data.estado}</h2>
                        <span style={{ padding: '4px 12px', background: 'rgba(0, 242, 254, 0.1)', borderRadius: '20px', color: 'var(--primary)', fontSize: '0.8rem', fontWeight: 600 }}>
                            {result.data.regiao}
                        </span>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
                        <div className="stat">
                            <p style={{ color: 'var(--text-dim)', fontSize: '0.75rem' }}>Valor UF</p>
                            <p style={{ fontWeight: 600 }}>R$ {result.data.vl_uf.toFixed(2)}</p>
                        </div>
                        <div className="stat">
                            <p style={{ color: 'var(--text-dim)', fontSize: '0.75rem' }}>Valor Região</p>
                            <p style={{ fontWeight: 600 }}>R$ {result.data.vl_regiao.toFixed(2)}</p>
                        </div>
                    </div>

                    <div style={{ borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: '15px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <Activity size={16} color="var(--text-dim)" />
                        <p style={{ color: 'var(--text-dim)', fontSize: '0.8rem' }}>Competência: {result.data.dt_competencia}</p>
                    </div>
                </div>
            )}

            {result && result.status === 'not_found' && (
                <div style={{ marginTop: '20px', textAlign: 'center', color: 'var(--text-dim)' }}>
                    Nenhum dado encontrado para "{result.uf}".
                </div>
            )}

            <footer style={{ marginTop: '40px', paddingTop: '20px', borderTop: '1px solid rgba(255,255,255,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.7rem', color: 'var(--text-dim)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Shield size={12} /> Proteção Industrial
                </div>
                <div>v1.2.0-Production</div>
            </footer>
        </div>
    );
}

export default App;
