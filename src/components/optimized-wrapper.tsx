'use client'
import { memo, useMemo, useCallback } from 'react'
import { useVirtualizer } from '@tanstack/react-virtual'

// Virtualized list for large datasets
export const VirtualizedList = memo(({ items, renderItem, height = 400 }: any) => {
  const parentRef = useRef<HTMLDivElement>(null)
  
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60,
    overscan: 5
  })
  
  return (
    <div ref={parentRef} style={{ height, overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: virtualItem.size,
              transform: `translateY(${virtualItem.start}px)`
            }}
          >
            {renderItem(items[virtualItem.index])}
          </div>
        ))}
      </div>
    </div>
  )
})

// Optimized image component
export const OptimizedImage = memo(({ src, alt, ...props }: any) => {
  const [loaded, setLoaded] = useState(false)
  
  return (
    <div style={{ position: 'relative' }}>
      {!loaded && <div className="animate-pulse bg-gray-300 w-full h-full" />}
      <img
        {...props}
        src={src}
        alt={alt}
        loading="lazy"
        decoding="async"
        onLoad={() => setLoaded(true)}
        style={{ display: loaded ? 'block' : 'none' }}
      />
    </div>
  )
})

// Memoized component wrapper
export const withOptimization = <T extends object>(Component: React.ComponentType<T>) => {
  return memo((props: T) => {
    const memoizedProps = useMemo(() => props, [JSON.stringify(props)])
    return <Component {...memoizedProps} />
  })
}