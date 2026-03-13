import React, { ReactElement } from 'react'
import { render, RenderOptions } from '@testing-library/react'
import { BrowserRouter } from 'react-router-dom'
import { AppProvider } from '@shopify/polaris'
import enTranslations from '@shopify/polaris/locales/en.json'

interface ProvidersProps {
  children: React.ReactNode
}

function AllProviders({ children }: ProvidersProps) {
  return (
    <AppProvider i18n={enTranslations}>
      <BrowserRouter>
        {children}
      </BrowserRouter>
    </AppProvider>
  )
}

function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) {
  return render(ui, { wrapper: AllProviders, ...options })
}

export { renderWithProviders }
export * from '@testing-library/react'
