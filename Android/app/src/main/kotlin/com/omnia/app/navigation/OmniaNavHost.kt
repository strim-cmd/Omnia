package com.omnia.app.navigation

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.omnia.app.AppContainer
import com.omnia.app.ui.AboutScreen
import com.omnia.feature.chat.ChatRoute
import com.omnia.feature.providers.ProvidersRoute
import com.omnia.feature.settings.SettingsRoute

/**
 * The navigation shell. Back behavior is the system default (BackHandler is not
 * required: Navigation Compose pops the back stack), and navigation never
 * reaches into the domain layer.
 */
@Composable
fun OmniaNavHost(
    container: AppContainer,
    modifier: Modifier = Modifier,
) {
    val navController = rememberNavController()
    NavHost(
        navController = navController,
        startDestination = OmniaDestination.CHAT.route,
        modifier = modifier,
        enterTransition = { EnterTransition.None },
        exitTransition = { ExitTransition.None },
        popEnterTransition = { EnterTransition.None },
        popExitTransition = { ExitTransition.None },
    ) {
        composable(OmniaDestination.CHAT.route) {
            ChatRoute(
                dependencies = container.chatDependencies,
                generationCoordinator = container.generationCoordinator,
                onOpenProviders = { navController.navigate(OmniaDestination.PROVIDERS.route) },
                onOpenSettings = { navController.navigate(OmniaDestination.SETTINGS.route) },
            )
        }
        composable(OmniaDestination.PROVIDERS.route) {
            ProvidersRoute(
                dependencies = container.providersDependencies,
                onBack = { navController.popBackStack() },
            )
        }
        composable(OmniaDestination.SETTINGS.route) {
            SettingsRoute(
                dependencies = container.settingsDependencies,
                onBack = { navController.popBackStack() },
                onOpenAbout = { navController.navigate(OmniaDestination.ABOUT.route) },
            )
        }
        composable(OmniaDestination.ABOUT.route) {
            AboutScreen(
                metadata = container.appMetadata,
                onBack = { navController.popBackStack() },
            )
        }
    }
}
