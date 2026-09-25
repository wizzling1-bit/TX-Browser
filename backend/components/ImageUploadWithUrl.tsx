'use client';

import React, { useState, useRef } from 'react';
import {
  UploadCloud,
  Link2,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Trash2,
  Copy,
  ExternalLink,
  Check,
} from 'lucide-react';
import { api } from '@/lib/api-client';

interface ImageUploadWithUrlProps {
  value: string;
  onChange: (url: string) => void;
  label?: string;
  helperText?: string;
}

export const ImageUploadWithUrl: React.FC<ImageUploadWithUrlProps> = ({
  value,
  onChange,
  label = 'Push Notification Hero Image (Optional)',
  helperText = 'Images appear as rich media banners in the expanded Android notification shade.',
}) => {
  const [activeTab, setActiveTab] = useState<'upload' | 'url'>('upload');
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [imageLoadError, setImageLoadError] = useState(false);

  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleCopy = async () => {
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // ignore
    }
  };

  const processAndUploadFile = (file: File) => {
    setUploadError(null);
    setImageLoadError(false);

    const validTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif', 'image/svg+xml'];
    if (!validTypes.includes(file.type.toLowerCase())) {
      setUploadError('Unsupported format. Please select PNG, JPG, WEBP, or GIF.');
      return;
    }

    const MAX_SIZE = 5 * 1024 * 1024;
    if (file.size > MAX_SIZE) {
      setUploadError(`File is too large (${(file.size / (1024 * 1024)).toFixed(1)}MB). Max size is 5MB.`);
      return;
    }

    setIsUploading(true);

    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const base64Data = reader.result as string;
        const res = await api.post<{
          success: boolean;
          url: string;
          filename: string;
          storageProvider: string;
        }>('/uploads/image', {
          filename: file.name,
          contentType: file.type,
          base64Data,
        });

        if (res.success && res.url) {
          onChange(res.url);
          setUploadError(null);
        } else {
          setUploadError('Upload failed. Server did not return a valid asset URL.');
        }
      } catch (err: any) {
        setUploadError(err?.message || 'Failed to upload image. Please check backend connection.');
      } finally {
        setIsUploading(false);
      }
    };

    reader.onerror = () => {
      setUploadError('Failed to read file from disk.');
      setIsUploading(false);
    };

    reader.readAsDataURL(file);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      processAndUploadFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      processAndUploadFile(e.target.files[0]);
    }
  };

  return (
    <div className="space-y-3">
      {/* Header & Tabs */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
        <div>
          <label className="block text-xs font-semibold text-tx-cream">{label}</label>
          {helperText && <p className="text-[11px] text-tx-textMuted mt-0.5">{helperText}</p>}
        </div>

        {/* Tab Switcher */}
        <div className="flex items-center p-1 rounded-xl bg-tx-surface border border-tx-border self-start sm:self-auto">
          <button
            type="button"
            onClick={() => setActiveTab('upload')}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-semibold transition-all ${
              activeTab === 'upload'
                ? 'bg-tx-card text-tx-cream shadow-sm'
                : 'text-tx-textMuted hover:text-tx-cream'
            }`}
          >
            <UploadCloud className="w-3.5 h-3.5 text-tx-gold" />
            <span>Upload File</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('url')}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-semibold transition-all ${
              activeTab === 'url'
                ? 'bg-tx-card text-tx-cream shadow-sm'
                : 'text-tx-textMuted hover:text-tx-cream'
            }`}
          >
            <Link2 className="w-3.5 h-3.5 text-tx-gold" />
            <span>Direct URL</span>
          </button>
        </div>
      </div>

      {/* Upload File Tab */}
      {activeTab === 'upload' && (
        <div>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/png,image/jpeg,image/webp,image/gif,image/svg+xml"
            onChange={handleFileChange}
            className="hidden"
          />

          <div
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => !isUploading && fileInputRef.current?.click()}
            className={`relative rounded-2xl border-2 border-dashed p-6 text-center cursor-pointer transition-all ${
              isDragging
                ? 'border-tx-gold bg-tx-gold/10 shadow-glow scale-[1.01]'
                : 'border-tx-border hover:border-tx-gold/60 bg-tx-surface hover:bg-tx-card/50'
            }`}
          >
            {isUploading ? (
              <div className="py-4 flex flex-col items-center justify-center gap-2.5">
                <Loader2 className="w-8 h-8 text-tx-gold animate-spin" />
                <div className="text-xs font-bold text-tx-cream">Uploading image to Supabase CDN...</div>
                <div className="text-[11px] text-tx-textMuted">Optimizing format and generating persistent link</div>
              </div>
            ) : (
              <div className="py-2 flex flex-col items-center justify-center gap-2">
                <div className="w-12 h-12 rounded-2xl bg-tx-card border border-tx-border flex items-center justify-center text-tx-gold shadow-sm">
                  <UploadCloud className="w-6 h-6" />
                </div>
                <div className="text-xs font-semibold text-tx-cream">
                  <span className="text-tx-gold hover:underline">Click to upload image</span> or drag and drop here
                </div>
                <div className="text-[11px] text-tx-textSubtle">
                  PNG, JPG, WEBP, or GIF (max 5MB) &bull; CDN auto-linked
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Image URL Tab */}
      {activeTab === 'url' && (
        <div className="relative">
          <div className="absolute left-3.5 top-1/2 -translate-y-1/2 text-tx-textSubtle pointer-events-none">
            <Link2 className="w-4 h-4" />
          </div>
          <input
            type="url"
            value={value}
            onChange={(e) => {
              onChange(e.target.value);
              setImageLoadError(false);
            }}
            placeholder="https://images.unsplash.com/... or hosted CDN image URL"
            className="w-full pl-10 pr-10 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs font-mono placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
          />
          {value && (
            <button
              type="button"
              onClick={() => onChange('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-tx-textSubtle hover:text-rose-400 transition-colors"
              title="Clear input"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          )}
        </div>
      )}

      {/* Upload Error Banner */}
      {uploadError && (
        <div className="p-3.5 rounded-xl bg-rose-950/40 border border-rose-800/50 flex items-start gap-2.5 text-xs text-rose-300 animate-fade-in">
          <AlertCircle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
          <div className="flex-1 font-medium">{uploadError}</div>
          <button
            type="button"
            onClick={() => setUploadError(null)}
            className="text-rose-400 hover:text-rose-200 font-bold"
          >
            &times;
          </button>
        </div>
      )}

      {/* Selected / Uploaded Image Preview & Metadata Card */}
      {value && (
        <div className="p-4 rounded-2xl bg-tx-surface border border-tx-border flex flex-col sm:flex-row items-center gap-4 shadow-card animate-fade-in">
          {/* Thumbnail */}
          <div className="relative w-24 h-18 sm:w-28 sm:h-18 rounded-xl overflow-hidden bg-black/40 border border-tx-border shrink-0 aspect-video">
            {imageLoadError ? (
              <div className="w-full h-full flex flex-col items-center justify-center p-1 text-center bg-rose-950/20 text-rose-400">
                <AlertCircle className="w-4 h-4" />
                <span className="text-[9px] mt-0.5 font-medium">Failed to load</span>
              </div>
            ) : (
              <img
                src={value}
                alt="Banner preview"
                className="w-full h-full object-cover"
                onError={() => setImageLoadError(true)}
              />
            )}
          </div>

          {/* Details & Actions */}
          <div className="flex-1 min-w-0 w-full space-y-1.5">
            <div className="flex items-center gap-2">
              <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-950/80 border border-emerald-700/60 text-emerald-300">
                <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                <span>Asset Ready</span>
              </span>
              {value.includes('supabase.co') && (
                <span className="text-[10px] text-tx-gold font-medium font-mono">
                  Supabase Cloud CDN
                </span>
              )}
            </div>

            <p className="text-[11px] font-mono text-tx-textSubtle truncate select-all">{value}</p>

            <div className="flex items-center gap-3 pt-1">
              <button
                type="button"
                onClick={handleCopy}
                className="inline-flex items-center gap-1 text-[11px] text-tx-textMuted hover:text-tx-cream font-medium transition-colors"
                title="Copy public URL"
              >
                {copied ? (
                  <>
                    <Check className="w-3 h-3 text-emerald-400" />
                    <span className="text-emerald-400 font-bold">Copied!</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3 h-3" />
                    <span>Copy Link</span>
                  </>
                )}
              </button>

              <span className="text-tx-border">&bull;</span>

              <a
                href={value}
                target="_blank"
                rel="noreferrer noopener"
                className="inline-flex items-center gap-1 text-[11px] text-tx-textMuted hover:text-tx-cream font-medium transition-colors"
              >
                <ExternalLink className="w-3 h-3" />
                <span>View Full</span>
              </a>

              <span className="text-tx-border">&bull;</span>

              <button
                type="button"
                onClick={() => {
                  onChange('');
                  setImageLoadError(false);
                }}
                className="inline-flex items-center gap-1 text-[11px] text-rose-400 hover:text-rose-300 font-medium transition-colors"
              >
                <Trash2 className="w-3 h-3" />
                <span>Remove</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
